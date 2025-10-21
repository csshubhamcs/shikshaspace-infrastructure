#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Change to services directory
cd ~/shikshaspace-infrastructure/services

# Check Envoy is running
check_envoy() {
    echo -e "${YELLOW}Checking Envoy status...${NC}"
    if ! curl -s http://localhost:9901/clusters > /dev/null 2>&1; then
        echo -e "${RED}✗ Envoy is not running!${NC}"
        echo -e "${YELLOW}Start Envoy with: cd ~/shikshaspace-infrastructure/envoy && docker compose up -d${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Envoy is running${NC}"
    echo ""
}

# Deploy single service with zero downtime
deploy_service() {
    local SERVICE=$1

    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Deploying: ${SERVICE}${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    # Pull latest image
    echo -e "${YELLOW}Pulling latest ${SERVICE} image...${NC}"
    docker compose pull $SERVICE

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to pull ${SERVICE} image${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Image pulled${NC}"
    echo ""

    # Zero downtime deployment
    echo -e "${YELLOW}Deploying with zero downtime...${NC}"
    docker rollout $SERVICE

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${SERVICE} deployed successfully${NC}"
    else
        echo -e "${RED}✗ ${SERVICE} deployment failed${NC}"
        return 1
    fi
    echo ""

    # Verify health
    echo -e "${YELLOW}Verifying health...${NC}"
    sleep 5

    CLUSTER_NAME="${SERVICE//-/_}_cluster"
    for i in {1..6}; do
        HEALTH=$(curl -s http://localhost:9901/clusters | grep "$CLUSTER_NAME" | grep "health_flags")

        if echo "$HEALTH" | grep -q "healthy"; then
            echo -e "${GREEN}✓ ${SERVICE} is healthy!${NC}"
            echo ""
            return 0
        fi

        echo -e "${BLUE}Health check $i/6...${NC}"
        sleep 5
    done

    echo -e "${RED}✗ ${SERVICE} not healthy after 30 seconds${NC}"
    return 1
}

# Deploy all services
deploy_all() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Deploying ALL Services${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    # Pull all images first
    echo -e "${YELLOW}Pulling all images...${NC}"
    docker compose pull

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to pull images${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ All images pulled${NC}"
    echo ""

    # Deploy services one by one
    local SERVICES=("user-service" "shikshaspace-service" "shikshaspace-ui")
    local FAILED=0

    for SERVICE in "${SERVICES[@]}"; do
        deploy_service "$SERVICE"

        if [ $? -ne 0 ]; then
            FAILED=$((FAILED + 1))
            echo -e "${YELLOW}Continue with remaining services? (y/n)${NC}"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo -e "${RED}Deployment aborted${NC}"
                exit 1
            fi
        fi

        echo -e "${YELLOW}Waiting 10 seconds before next deployment...${NC}"
        sleep 10
        echo ""
    done

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}======================================${NC}"
        echo -e "${GREEN}✓ ALL SERVICES DEPLOYED SUCCESSFULLY${NC}"
        echo -e "${GREEN}======================================${NC}"
    else
        echo -e "${YELLOW}======================================${NC}"
        echo -e "${YELLOW}⚠ Deployment completed with $FAILED failure(s)${NC}"
        echo -e "${YELLOW}======================================${NC}"
    fi
}

# Main logic
echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ShikshaSpace Deployment Script   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo ""

check_envoy

if [ -z "$1" ]; then
    # No service specified - deploy all
    deploy_all
else
    # Specific service
    SERVICE=$1

    # Validate service name
    if [[ ! "$SERVICE" =~ ^(user-service|shikshaspace-service|shikshaspace-ui)$ ]]; then
        echo -e "${RED}Invalid service name: $SERVICE${NC}"
        echo -e "${YELLOW}Valid services: user-service, shikshaspace-service, shikshaspace-ui${NC}"
        exit 1
    fi

    deploy_service "$SERVICE"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}======================================${NC}"
        echo -e "${GREEN}✓ DEPLOYMENT COMPLETE${NC}"
        echo -e "${GREEN}======================================${NC}"
    else
        exit 1
    fi
fi
