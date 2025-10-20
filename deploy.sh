#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Deploying ALL Services${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check Envoy
echo -e "${YELLOW}Checking Envoy status...${NC}"
if ! curl -s http://localhost:9901/clusters > /dev/null 2>&1; then
    echo -e "${RED}✗ Envoy is not running!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Envoy is running${NC}"
echo ""

# Pull all images first
echo -e "${YELLOW}Step 1: Pulling all images from registry...${NC}"
docker compose pull

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to pull images${NC}"
    exit 1
fi
echo -e "${GREEN}✓ All images pulled${NC}"
echo ""

# Get list of services (exclude Keycloak if you want)
SERVICES=$(docker compose config --services)
TOTAL_SERVICES=$(echo "$SERVICES" | wc -l)
CURRENT=0

echo -e "${BLUE}Services to deploy:${NC}"
echo "$SERVICES"
echo ""

# Deploy each service
for SERVICE in $SERVICES; do
    CURRENT=$((CURRENT + 1))

    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}[$CURRENT/$TOTAL_SERVICES] Deploying: ${SERVICE}${NC}"
    echo -e "${BLUE}======================================${NC}"

    # Deploy service
    docker rollout $SERVICE

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${SERVICE} deployed successfully${NC}"
    else
        echo -e "${RED}✗ ${SERVICE} deployment failed${NC}"
        echo -e "${YELLOW}Continue with remaining services? (y/n)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deployment aborted${NC}"
            exit 1
        fi
    fi

    echo ""
    echo -e "${YELLOW}Waiting 10 seconds before next deployment...${NC}"
    sleep 10
    echo ""
done

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}✓ ALL SERVICES DEPLOYED${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Final health check
echo -e "${BLUE}Final Health Check:${NC}"
curl -s http://localhost:9901/clusters | grep "health_flags"
echo ""

echo -e "${BLUE}View detailed status:${NC}"
echo -e "  Envoy Admin: https://envoy.shubhamsinghrajput.com/clusters"
echo -e "  Docker Status: docker compose ps"
