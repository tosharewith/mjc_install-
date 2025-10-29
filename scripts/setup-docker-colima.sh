#!/bin/bash
# 🐳 Setup Docker to use Colima
# Run this before migration: source ./scripts/setup-docker-colima.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 Setting up Docker with Colima...${NC}"
echo ""

# Check if Colima is running
if ! colima status > /dev/null 2>&1; then
    echo -e "${RED}❌ Colima is not running${NC}"
    echo -e "${YELLOW}Starting Colima...${NC}"
    colima start
    sleep 5
fi

# Show Colima status
echo -e "${GREEN}✅ Colima Status:${NC}"
colima status | grep -E "(running|arch|runtime|socket)"
echo ""

# Set Docker socket
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
echo -e "${GREEN}✅ Set DOCKER_HOST=${DOCKER_HOST}${NC}"

# Use colima context
docker context use colima > /dev/null 2>&1

# Test Docker
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker is working!${NC}"
    docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}'
else
    echo -e "${RED}❌ Docker still not working${NC}"
    echo ""
    echo -e "${YELLOW}Try manually:${NC}"
    echo -e "  1. unset DOCKER_HOST"
    echo -e "  2. docker context use colima"
    echo -e "  3. docker ps"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Docker is ready for migration!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Now run:${NC}"
echo -e "  ${BLUE}./scripts/migrate-images-manual.sh${NC}"
echo ""
