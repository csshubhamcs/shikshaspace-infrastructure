#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ENVOY HEALTH MONITORING DASHBOARD   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

while true; do
    # Get cluster health
    HEALTH_OUTPUT=$(curl -s http://localhost:9901/clusters | grep "health_flags")

    # Service status
    echo -e "${BLUE}Service Health Status:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check each service
    for service in "ui_cluster" "user_service_cluster" "shikshaspace_service_cluster" "keycloak_cluster"; do
        SERVICE_HEALTH=$(echo "$HEALTH_OUTPUT" | grep "$service")

        if echo "$SERVICE_HEALTH" | grep -q "healthy"; then
            echo -e "  ${GREEN}✓${NC} $service: ${GREEN}HEALTHY${NC}"
        else
            echo -e "  ${RED}✗${NC} $service: ${RED}UNHEALTHY${NC}"
        fi
    done

    echo ""
    echo -e "${BLUE}Request Statistics:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get request stats
    TOTAL_REQ=$(curl -s http://localhost:9901/stats | grep "downstream_rq_total" | head -1 | awk '{print $2}')
    ERROR_REQ=$(curl -s http://localhost:9901/stats | grep "downstream_rq_5xx" | head -1 | awk '{print $2}')

    echo -e "  Total Requests: ${BLUE}${TOTAL_REQ}${NC}"
    echo -e "  Error Requests: ${RED}${ERROR_REQ}${NC}"

    echo ""
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo -e "${YELLOW}Refreshing in 5 seconds...${NC}"
    echo ""

    sleep 5
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   ENVOY HEALTH MONITORING DASHBOARD   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
done
