#!/bin/bash

# =====================================================
# VINAACADEMY DOCKER SWARM DEPLOYMENT SCRIPT
# =====================================================
# This script loads environment variables from .env file
# and deploys the stack to Docker Swarm
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
STACK_FILE="${SCRIPT_DIR}/docker-stack.yml"
STACK_NAME="vinaacademy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   VINAACADEMY DOCKER SWARM DEPLOYMENT${NC}"
echo -e "${GREEN}================================================${NC}"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo -e "${YELLOW}Please create .env file from .env.example:${NC}"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your configuration"
    exit 1
fi

# Check if docker-stack.yml exists
if [ ! -f "$STACK_FILE" ]; then
    echo -e "${RED}Error: docker-stack.yml not found!${NC}"
    exit 1
fi

# Check if Docker Swarm is initialized
if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
    echo -e "${RED}Error: Docker Swarm is not initialized!${NC}"
    echo -e "${YELLOW}Initialize with: docker swarm init${NC}"
    exit 1
fi

# Load environment variables from .env file
echo -e "${YELLOW}Loading environment variables from .env...${NC}"
export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)

# Verify critical environment variables
REQUIRED_VARS=(
    "POSTGRES_URL"
    "POSTGRES_USERNAME"
    "POSTGRES_PASSWORD"
    "MINIO_ENDPOINT"
    "MINIO_ACCESS_KEY"
    "MINIO_SECRET_KEY"
    "APPLICATION_HMAC_SECRET"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

echo -e "${GREEN}✓ All required environment variables loaded${NC}"

# Check node labels
echo -e "${YELLOW}Checking node labels...${NC}"

TOOLS_NODE=$(docker node ls --filter "node.label.role=tools" -q 2>/dev/null || true)
SERVICE_NODE=$(docker node ls --filter "node.label.role=worker-service" -q 2>/dev/null || true)

if [ -z "$TOOLS_NODE" ]; then
    echo -e "${YELLOW}Warning: No node with 'role=tools' label found${NC}"
    echo "  Add label with: docker node update --label-add role=tools <node-name>"
fi

if [ -z "$SERVICE_NODE" ]; then
    echo -e "${YELLOW}Warning: No node with 'role=worker-service' label found${NC}"
    echo "  Add label with: docker node update --label-add role=worker-service <node-name>"
fi

# Deploy or update stack
echo -e "${YELLOW}Deploying stack '${STACK_NAME}'...${NC}"

docker stack deploy -c "$STACK_FILE" "$STACK_NAME" --with-registry-auth

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   DEPLOYMENT INITIATED SUCCESSFULLY!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  View services:    docker stack services $STACK_NAME"
echo "  View tasks:       docker stack ps $STACK_NAME"
echo "  View logs:        docker service logs ${STACK_NAME}_<service-name>"
echo "  Remove stack:     docker stack rm $STACK_NAME"
echo ""
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 5
docker stack services "$STACK_NAME"
