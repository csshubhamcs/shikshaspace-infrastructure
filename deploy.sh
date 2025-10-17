#!/bin/bash

echo "======================================"
echo "Deploying ALL Services"
echo "======================================"

# Pull all new images
echo "Pulling all images from registry..."
docker compose pull

if [ $? -ne 0 ]; then
    echo "✗ Failed to pull images"
    exit 1
fi

# Get all services except traefik
SERVICES=$(docker compose config --services | grep -v traefik)

echo ""
echo "Services to deploy:"
echo "$SERVICES"
echo ""

# Deploy each service with zero downtime
for SERVICE in $SERVICES; do
    echo ">>> Deploying $SERVICE..."
    docker rollout $SERVICE

    if [ $? -eq 0 ]; then
        echo "✓ $SERVICE deployed successfully"
    else
        echo "✗ $SERVICE deployment failed"
        exit 1
    fi

    echo ""
    sleep 3
done

echo "======================================"
echo "✓ ALL SERVICES DEPLOYED SUCCESSFULLY"
echo "======================================"
