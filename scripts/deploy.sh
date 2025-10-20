#!/bin/bash
# deploy.sh - Unified Zero-Downtime Deployment Script
# Usage:
#   ./deploy.sh all                          # Deploy all services
#   ./deploy.sh user-service v1.0.39         # Deploy specific service
#   ./deploy.sh shikshaspace-service latest  # Deploy with version

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/../services/docker-compose.yml"
ENVOY_CHECK_URL="http://localhost:9901/clusters"
HEALTH_WAIT_ATTEMPTS=12
HEALTH_WAIT_INTERVAL=5

# Service registry
declare -A SERVICE_PORTS=(
    ["user-service"]="7501:7511"
    ["shikshaspace-service"]="7502:7512"
    ["shikshaspace-ui"]="7500:7510"
)

# ════════════════════════════════════════════════════════════════
# Helper Functions
# ════════════════════════════════════════════════════════════════

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_header() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

check_envoy() {
    if ! curl -sf "$ENVOY_CHECK_URL" > /dev/null 2>&1; then
        log_error "Envoy is not running on port 9901"
        log_info "Start Envoy: cd envoy && docker compose up -d"
        exit 1
    fi
    log_success "Envoy is running"
}

get_active_color() {
    local service=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service}-blue$"; then
        echo "blue"
    else
        echo "green"
    fi
}

get_inactive_color() {
    local active=$1
    [[ "$active" == "blue" ]] && echo "green" || echo "blue"
}

wait_for_health() {
    local container=$1
    local port=$2

    log_info "Waiting for $container health check..."

    for i in $(seq 1 $HEALTH_WAIT_ATTEMPTS); do
        sleep $HEALTH_WAIT_INTERVAL

        if docker inspect "$container" 2>/dev/null | grep -q '"Status": "healthy"'; then
            log_success "$container is healthy"
            return 0
        fi

        echo -ne "${BLUE}Attempt $i/$HEALTH_WAIT_ATTEMPTS...${NC}\r"
    done

    log_error "$container failed health check"
    docker logs "$container" --tail 50
    return 1
}

verify_envoy_routing() {
    local service=$1
    local cluster_name="${service//-/_}_cluster"

    log_info "Verifying Envoy routing for $cluster_name..."
    sleep 10  # Wait for Envoy health check cycle

    local envoy_status
    envoy_status=$(curl -s "$ENVOY_CHECK_URL" | grep "$cluster_name" || true)

    local healthy_count
    healthy_count=$(echo "$envoy_status" | grep -c "health_flags::healthy" || echo "0")

    if [[ "$healthy_count" -ge 1 ]]; then
        log_success "Envoy routing to $cluster_name ($healthy_count healthy instances)"
        return 0
    else
        log_warning "No healthy instances detected for $cluster_name"
        echo "$envoy_status"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════
# Deployment Functions
# ════════════════════════════════════════════════════════════════

deploy_service() {
    local service=$1
    local version=${2:-latest}

    log_header "Deploying $service:$version"

    # Validate service
    if [[ ! -v "SERVICE_PORTS[$service]" ]]; then
        log_error "Unknown service: $service"
        log_info "Available: ${!SERVICE_PORTS[@]}"
        exit 1
    fi

    # Parse ports
    IFS=':' read -r blue_port green_port <<< "${SERVICE_PORTS[$service]}"

    # Determine colors
    local active_color
    active_color=$(get_active_color "$service")
    local inactive_color
    inactive_color=$(get_inactive_color "$active_color")

    local active_container="${service}-${active_color}"
    local inactive_container="${service}-${inactive_color}"
    local inactive_port
    [[ "$inactive_color" == "blue" ]] && inactive_port=$blue_port || inactive_port=$green_port

    log_info "Active: $active_color | Deploying to: $inactive_color"

    # Set version environment variable
    local env_var="${service^^}_VERSION"
    env_var="${env_var//-/_}"
    export "$env_var=$version"

    # Pull image
    log_info "Pulling $service:$version..."
    docker compose -f "$COMPOSE_FILE" pull "$inactive_container" || {
        log_error "Failed to pull image"
        exit 1
    }
    log_success "Image pulled"

    # Start inactive container
    log_info "Starting $inactive_container..."
    docker compose -f "$COMPOSE_FILE" --profile "$inactive_color" up -d "$inactive_container" || {
        log_error "Failed to start container"
        exit 1
    }

    # Wait for health
    wait_for_health "$inactive_container" "$inactive_port" || exit 1

    # Verify Envoy routing
    verify_envoy_routing "$service" || log_warning "Envoy verification failed, but continuing..."

    # Extra wait for traffic shift
    log_info "Waiting 20s for Envoy to shift traffic to $inactive_color..."
    sleep 20

    # Stop old container
    log_info "Stopping $active_container..."
    docker compose -f "$COMPOSE_FILE" stop "$active_container"
    docker compose -f "$COMPOSE_FILE" rm -f "$active_container"

    log_success "Deployment complete! Now running on $inactive_color"
    docker ps --filter "name=$service" --format "table {{.Names}}\t{{.Status}}"
}

deploy_all() {
    log_header "Deploying ALL Services"

    check_envoy

    # Pull all images
    log_info "Pulling all images..."
    docker compose -f "$COMPOSE_FILE" pull
    log_success "All images pulled"

    # Deploy each service
    for service in "${!SERVICE_PORTS[@]}"; do
        deploy_service "$service" "latest"
        echo ""
    done

    log_success "All services deployed"
    log_info "Monitor: ./scripts/monitor.sh"
}

# ════════════════════════════════════════════════════════════════
# Main
# ════════════════════════════════════════════════════════════════

main() {
    cd "$SCRIPT_DIR/.."

    check_envoy

    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <service|all> [version]"
        log_info "Examples:"
        log_info "  $0 all"
        log_info "  $0 user-service v1.0.39"
        log_info "  $0 shikshaspace-ui latest"
        exit 1
    fi

    if [[ "$1" == "all" ]]; then
        deploy_all
    else
        deploy_service "$1" "${2:-latest}"
    fi
}

main "$@"
