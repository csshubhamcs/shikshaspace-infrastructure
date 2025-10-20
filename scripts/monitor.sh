#!/bin/bash
# monitor.sh - Real-time Envoy Health Monitoring

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ENVOY_ADMIN="http://localhost:9901"

print_header() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     ENVOY HEALTH MONITORING DASHBOARD            ║${NC}"
    echo -e "${CYAN}║     Updated: $(date '+%Y-%m-%d %H:%M:%S')                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_cluster_health() {
    local cluster=$1
    local health_data
    health_data=$(curl -s "$ENVOY_ADMIN/clusters" | grep "$cluster" | grep "health_flags")

    local healthy_count
    healthy_count=$(echo "$health_data" | grep -c "health_flags::healthy" || echo "0")

    local total_count
    total_count=$(echo "$health_data" | wc -l)

    if [[ "$healthy_count" -gt 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $cluster: ${GREEN}$healthy_count/$total_count healthy${NC}"
    else
        echo -e "  ${RED}✗${NC} $cluster: ${RED}$healthy_count/$total_count healthy${NC}"
    fi
}

while true; do
    print_header

    echo -e "${BLUE}Service Health Status:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_cluster_health "ui_cluster"
    check_cluster_health "user_service_cluster"
    check_cluster_health "shikshaspace_service_cluster"
    check_cluster_health "keycloak_cluster"

    echo ""
    echo -e "${BLUE}Request Statistics:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    total_req=$(curl -s "$ENVOY_ADMIN/stats" | grep "^http.ingress_http.downstream_rq_total:" | awk '{print $2}')
    error_5xx=$(curl -s "$ENVOY_ADMIN/stats" | grep "^http.ingress_http.downstream_rq_5xx:" | awk '{print $2}')
    error_4xx=$(curl -s "$ENVOY_ADMIN/stats" | grep "^http.ingress_http.downstream_rq_4xx:" | awk '{print $2}')

    echo -e "  Total Requests:  ${CYAN}${total_req:-0}${NC}"
    echo -e "  4xx Errors:      ${YELLOW}${error_4xx:-0}${NC}"
    echo -e "  5xx Errors:      ${RED}${error_5xx:-0}${NC}"

    echo ""
    echo -e "${YELLOW}Press Ctrl+C to exit | Refreshing in 5s...${NC}"

    sleep 5
done
