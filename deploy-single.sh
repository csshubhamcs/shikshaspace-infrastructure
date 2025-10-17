#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./deploy-single.sh <service-name>"
    echo "Example: ./deploy-single.sh user-service"
    exit 1
fi

SERVICE=$1

echo "======================================"
echo "Deploying Single Service: $SERVICE"
echo "======================================"

# Pull latest image
echo "Pulling $SERVICE image..."
docker compose pull $SERVICE

if [ $? -ne 0 ]; then
    echo "✗ Failed to pull $SERVICE image"
    exit 1
fi

# Deploy with zero downtime
echo ">>> Deploying $SERVICE..."
docker rollout $SERVICE

if [ $? -eq 0 ]; then
    echo "✓ $SERVICE deployed successfully"
else
    echo "✗ $SERVICE deployment failed"
    exit 1
fi

echo "======================================"
echo "✓ DEPLOYMENT COMPLETE"
echo "======================================"
