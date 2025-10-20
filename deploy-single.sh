#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Usage: ./deploy-single.sh <service-name>${NC}"
    echo "Example: ./deploy-single.sh user-service"
    exit 1
fi

SERVICE=$1

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Deploying Service: ${SERVICE}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check Envoy is running
echo -e "${YELLOW}[1/5] Checking Envoy status...${NC}"
if ! curl -s http://localhost:9901/clusters > /dev/null 2>&1; then
    echo -e "${RED}✗ Envoy is not running! Start Envoy first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Envoy is running${NC}"
echo ""

# Check current service health
echo -e "${YELLOW}[2/5] Checking current ${SERVICE} health...${NC}"
CLUSTER_NAME="${SERVICE//-/_}_cluster"
CURRENT_HEALTH=$(curl -s http://localhost:9901/clusters | grep "$CLUSTER_NAME" | grep "health_flags")
echo "$CURRENT_HEALTH"

if echo "$CURRENT_HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Service is currently healthy${NC}"
else
    echo -e "${YELLOW}⚠ Service is currently unhealthy or not found${NC}"
fi
echo ""

# Pull latest image
echo -e "${YELLOW}[3/5] Pulling latest ${SERVICE} image...${NC}"
docker compose pull $SERVICE

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to pull ${SERVICE} image${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image pulled successfully${NC}"
echo ""

# Deploy with zero downtime
echo -e "${YELLOW}[4/5] Deploying ${SERVICE} with zero downtime...${NC}"
echo -e "${BLUE}>>> docker-rollout will:${NC}"
echo -e "${BLUE}    1. Start new container${NC}"
echo -e "${BLUE}    2. Wait for health check (/actuator/health)${NC}"
echo -e "${BLUE}    3. Keep old container running${NC}"
echo -e "${BLUE}    4. Stop old container only when new is healthy${NC}"
echo ""

docker rollout $SERVICE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ${SERVICE} deployed successfully${NC}"
else
    echo -e "${RED}✗ ${SERVICE} deployment failed${NC}"
    exit 1
fi
echo ""

# Verify health after deployment
echo -e "${YELLOW}[5/5] Verifying ${SERVICE} health after deployment...${NC}"
sleep 5  # Wait for Envoy to detect new instance

for i in {1..6}; do
    echo -e "${BLUE}Health check attempt $i/6...${NC}"
    NEW_HEALTH=$(curl -s http://localhost:9901/clusters | grep "$CLUSTER_NAME" | grep "health_flags")
    echo "$NEW_HEALTH"

    if echo "$NEW_HEALTH" | grep -q "healthy"; then
        echo -e "${GREEN}✓ Service is healthy after deployment!${NC}"
        echo ""
        echo -e "${GREEN}======================================${NC}"
        echo -e "${GREEN}✓ DEPLOYMENT COMPLETE${NC}"
        echo -e "${GREEN}======================================${NC}"
        echo ""
        echo -e "${BLUE}Check logs:${NC} sudo docker logs ${SERVICE} -f"
        echo -e "${BLUE}Monitor Envoy:${NC} https://envoy.shubhamsinghrajput.com/clusters"
        exit 0
    fi

    sleep 5
done

echo -e "${RED}✗ Service not healthy after 30 seconds${NC}"
echo -e "${YELLOW}Check logs: sudo docker logs ${SERVICE}${NC}"
exit 1
