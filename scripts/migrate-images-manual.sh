#!/bin/bash
# 🐳 Manual Image Migration Script
# Uses: IBM Cloud CLI + Docker (via Colima)
# Created: 2025-10-29

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🐳 Image Migration Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ====================
# 1. SETUP DOCKER CONTEXT
# ====================
echo -e "${YELLOW}[1/7] Setting up Docker context...${NC}"

# Set Colima socket
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

# Test Docker
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker not working. Trying to fix context...${NC}"

    # Try to use colima context
    docker context use colima 2>/dev/null || true

    if ! docker ps > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker still not working. Is Colima running?${NC}"
        echo -e "${YELLOW}Run: colima start${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Docker is working via Colima${NC}"
docker version --format '   Client: {{.Client.Version}} | Server: {{.Server.Version}}'
echo ""

# ====================
# 2. CHECK IBM CLOUD CLI
# ====================
echo -e "${YELLOW}[2/7] Checking IBM Cloud CLI...${NC}"

if ! command -v ibmcloud &> /dev/null; then
    echo -e "${RED}❌ ibmcloud CLI not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IBM Cloud CLI:${NC} $(ibmcloud --version | head -1)"
echo -e "${GREEN}   Current target:${NC}"
ibmcloud target | grep -E "(Account|Region|Resource group)" || true
echo ""

# ====================
# 3. GET TARGET REGISTRY
# ====================
echo -e "${YELLOW}[3/7] Determining target registry...${NC}"

# Source config if exists
if [ -f "config/migration.env" ]; then
    source config/migration.env
fi

# Target IBM Container Registry - Brazil Region
TARGET_ICR_REGION="br.icr.io"
TARGET_NAMESPACE="br-ibm-images"

echo -e "${BLUE}   Target IBM Registry:${NC} ${TARGET_ICR_REGION}"
echo -e "${BLUE}   Target Namespace:${NC} ${TARGET_NAMESPACE}"

# List namespaces (switch to Brazil region first)
echo -e "${BLUE}   Setting region to Brazil...${NC}"
ibmcloud cr region-set ${TARGET_ICR_REGION} > /dev/null 2>&1

echo -e "${BLUE}   Available namespaces:${NC}"
ibmcloud cr namespaces | tail -n +3 | head -5

# Default target: br.icr.io/br-ibm-images
DEFAULT_TARGET="${TARGET_ICR_REGION}/${TARGET_NAMESPACE}"

# Allow override via environment variable or config file
TARGET_REGISTRY=${TARGET_REGISTRY:-$DEFAULT_TARGET}

# Optional: JFrog Artifactory prefix (if set)
# Example: JFROG_PREFIX="artifactory.company.com/docker-remote/"
if [ -n "$JFROG_PREFIX" ]; then
    echo -e "${YELLOW}   JFrog Artifactory Prefix:${NC} ${JFROG_PREFIX}"
    echo -e "${YELLOW}   Images will be accessible via:${NC} ${JFROG_PREFIX}${TARGET_REGISTRY#*/}"
fi

echo ""
echo -e "${GREEN}   Target Registry:${NC} ${TARGET_REGISTRY}"
echo ""

# ====================
# 4. LOGIN TO REGISTRIES
# ====================
echo -e "${YELLOW}[4/7] Logging into registries...${NC}"

# Login to IBM Container Registry
echo -e "${BLUE}   Logging into IBM CR...${NC}"
ibmcloud cr login

# If target is AWS ECR, login there too
if [[ "$TARGET_REGISTRY" == *"ecr"* ]]; then
    echo -e "${BLUE}   Logging into AWS ECR...${NC}"
    AWS_REGION=${AWS_REGION:-us-east-1}
    AWS_ACCOUNT_ID=$(echo $TARGET_REGISTRY | cut -d'.' -f1)

    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
fi

echo -e "${GREEN}✅ Logged into registries${NC}"
echo ""

# ====================
# 5. DEFINE IMAGES TO MIGRATE
# ====================
echo -e "${YELLOW}[5/7] Defining images to migrate...${NC}"

# Array of images: SOURCE_IMAGE|TARGET_NAME|TAG
# NOTE: Only migrating PRIVATE images we own/built
#       Public images (milvus, kafka, etc) NOT migrated due to licensing
IMAGES=(
    # Images from ACTUAL Kubernetes deployments (airflow-test + mmjc-test)
    # Source: icr.io/mjc-cr (GLOBAL region)
    # Verified from: kubectl get pods -n <namespace> -o jsonpath

    # From airflow-test namespace (1 image)
    "icr.io/mjc-cr/mmjc-airflow-service:latest|mmjc-airflow-service|latest"

    # From mmjc-test namespace - MCP Services (4 images)
    "icr.io/mjc-cr/mcp-arc-s3-tool:2.1.17-amd64|mcp-arc-s3-tool|2.1.17-amd64"
    "icr.io/mjc-cr/mcp-milvus-db:0.0.1|mcp-milvus-db|0.0.1"
    "icr.io/mjc-cr/mcp-context-forge:0.6.0|mcp-context-forge|0.6.0"
    "icr.io/mjc-cr/go-mcp-git-s3:1.0.31|go-mcp-git-s3|1.0.31"

    # From mmjc-test namespace - Validators (1 image)
    "icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64|mjc-mermaid-validator|1.0.17-llm-ready-amd64"

    # From mmjc-test namespace - MMJC Services (4 images)
    "icr.io/mjc-cr/mmjc-po:0.0.1|mmjc-po|0.0.1"
    "icr.io/mjc-cr/mmjc-agents:0.0.1|mmjc-agents|0.0.1"
    "icr.io/mjc-cr/mmjc-frontend:0.0.1|mmjc-frontend|0.0.1"

    # From mmjc-test namespace - File Services (2 images)
    "icr.io/mjc-cr/api-file-zip-s3:1.0.2|api-file-zip-s3|1.0.2"
    "icr.io/mjc-cr/cos-file-organizer:0.1.0|cos-file-organizer|0.1.0"

    # From mmjc-test namespace - Understanding Agent (1 image)
    "icr.io/mjc-cr/understanding-agent-arc:v1.6.57|understanding-agent-arc|v1.6.57"
)

# PUBLIC IMAGES NOT MIGRATED (use from original registries):
# - milvusdb/milvus:v2.5.15              (from docker.io)
# - docker.io/milvusdb/etcd:3.5.18-r1    (from docker.io)
# - docker.io/bitnami/kafka:3.1.0...     (from docker.io)
# - docker.io/bitnami/zookeeper:3.7.0... (from docker.io)
# - quay.io/prometheus/statsd-exporter   (from quay.io)
# Reason: Licensing restrictions - we cannot redistribute

echo -e "${GREEN}   Found ${#IMAGES[@]} images to migrate${NC}"
echo ""

# ====================
# 6. MIGRATE IMAGES
# ====================
echo -e "${YELLOW}[6/7] Migrating images...${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
SKIPPED_COUNT=0

for IMAGE_SPEC in "${IMAGES[@]}"; do
    IFS='|' read -r SOURCE_IMAGE TARGET_NAME TAG <<< "$IMAGE_SPEC"

    TARGET_IMAGE="${TARGET_REGISTRY}/${TARGET_NAME}:${TAG}"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 Migrating:${NC} ${SOURCE_IMAGE}"
    echo -e "${BLUE}   → Target:${NC} ${TARGET_IMAGE}"
    echo ""

    # Check if target already exists
    if docker manifest inspect "$TARGET_IMAGE" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Image already exists in target registry, skipping...${NC}"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        echo ""
        continue
    fi

    # Pull source image
    echo -e "${BLUE}   [1/3] Pulling source image...${NC}"
    if docker pull "$SOURCE_IMAGE"; then
        echo -e "${GREEN}   ✅ Pull successful${NC}"
    else
        echo -e "${RED}   ❌ Pull failed${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo ""
        continue
    fi

    # Tag for target registry
    echo -e "${BLUE}   [2/3] Tagging image...${NC}"
    docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
    echo -e "${GREEN}   ✅ Tagged${NC}"

    # Push to target registry
    echo -e "${BLUE}   [3/3] Pushing to target registry...${NC}"
    if docker push "$TARGET_IMAGE"; then
        echo -e "${GREEN}   ✅ Push successful${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}   ❌ Push failed${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # Clean up local image (optional)
    # docker rmi "$SOURCE_IMAGE" "$TARGET_IMAGE" 2>/dev/null || true

    echo ""
done

# ====================
# 7. SUMMARY
# ====================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📊 Migration Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ Successfully migrated: ${SUCCESS_COUNT}${NC}"
echo -e "${YELLOW}⚠️  Skipped (already exist): ${SKIPPED_COUNT}${NC}"
echo -e "${RED}❌ Failed: ${FAIL_COUNT}${NC}"
echo ""
echo -e "${BLUE}Target Registry:${NC} ${TARGET_REGISTRY}"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}⚠️  Some images failed to migrate. Check logs above.${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Update kustomization.yaml files with new image references"
echo -e "  2. Run: ${BLUE}./scripts/update-image-refs.sh${NC}"
echo -e "  3. Deploy: ${BLUE}kubectl apply -k kustomize/...${NC}"
echo ""
