#!/bin/bash
# 🐳 Parallel Image Migration Script
# Uses: IBM Cloud CLI + Docker (via Colima)
# Migrates multiple images in parallel for faster completion
# Created: 2025-10-29

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Parallel Image Migration Script${NC}"
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
    echo -e "${RED}❌ Docker not working${NC}"
    exit 1
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

# Switch to Brazil region
ibmcloud cr region-set ${TARGET_ICR_REGION} > /dev/null 2>&1

# Default target: br.icr.io/br-ibm-images
DEFAULT_TARGET="${TARGET_ICR_REGION}/${TARGET_NAMESPACE}"
TARGET_REGISTRY=${TARGET_REGISTRY:-$DEFAULT_TARGET}

echo -e "${GREEN}   Target Registry:${NC} ${TARGET_REGISTRY}"
echo ""

# ====================
# 4. LOGIN TO REGISTRIES
# ====================
echo -e "${YELLOW}[4/7] Logging into registries...${NC}"

# Login to IBM Container Registry
ibmcloud cr login > /dev/null 2>&1

echo -e "${GREEN}✅ Logged into registries${NC}"
echo ""

# ====================
# 5. DEFINE IMAGES TO MIGRATE
# ====================
echo -e "${YELLOW}[5/7] Defining images to migrate...${NC}"

# Array of images: SOURCE_IMAGE|TARGET_NAME|TAG
IMAGES=(
    # Images from ACTUAL deployments (airflow-test + milvus-mmjc-test)
    # Source: icr.io/mjc-cr (GLOBAL region)

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

echo -e "${GREEN}   Found ${#IMAGES[@]} images to migrate${NC}"
echo ""

# ====================
# 6. MIGRATE IMAGES IN PARALLEL
# ====================
echo -e "${YELLOW}[6/7] Migrating images in parallel...${NC}"
echo -e "${BLUE}   Starting ${#IMAGES[@]} parallel migrations...${NC}"
echo ""

# Create temp directory for logs
LOG_DIR=$(mktemp -d)
echo -e "${BLUE}   Logs directory: ${LOG_DIR}${NC}"
echo ""

# Function to migrate a single image
migrate_image() {
    local IMAGE_SPEC=$1
    local LOG_FILE=$2
    local IMAGE_NUM=$3

    IFS='|' read -r SOURCE_IMAGE TARGET_NAME TAG <<< "$IMAGE_SPEC"
    TARGET_IMAGE="${TARGET_REGISTRY}/${TARGET_NAME}:${TAG}"

    {
        echo "[$IMAGE_NUM] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[$IMAGE_NUM] 📦 Migrating: ${SOURCE_IMAGE}"
        echo "[$IMAGE_NUM]    → Target: ${TARGET_IMAGE}"
        echo ""

        # Check if target already exists
        if docker manifest inspect "$TARGET_IMAGE" > /dev/null 2>&1; then
            echo "[$IMAGE_NUM] ⚠️  Already exists, skipping..."
            echo "SKIPPED"
            return 0
        fi

        # Pull source image
        echo "[$IMAGE_NUM]    [1/3] Pulling source image..."
        if docker pull "$SOURCE_IMAGE" >> "$LOG_FILE" 2>&1; then
            echo "[$IMAGE_NUM]    ✅ Pull successful"
        else
            echo "[$IMAGE_NUM]    ❌ Pull failed"
            echo "FAILED"
            return 1
        fi

        # Tag for target registry
        echo "[$IMAGE_NUM]    [2/3] Tagging image..."
        docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
        echo "[$IMAGE_NUM]    ✅ Tagged"

        # Push to target registry
        echo "[$IMAGE_NUM]    [3/3] Pushing to target registry..."
        if docker push "$TARGET_IMAGE" >> "$LOG_FILE" 2>&1; then
            echo "[$IMAGE_NUM]    ✅ Push successful"
            echo "SUCCESS"
            return 0
        else
            echo "[$IMAGE_NUM]    ❌ Push failed"
            echo "FAILED"
            return 1
        fi
    } | tee -a "$LOG_FILE"
}

export -f migrate_image
export TARGET_REGISTRY
export LOG_DIR

# Launch all migrations in parallel
PIDS=()
IMAGE_NUM=1

for IMAGE_SPEC in "${IMAGES[@]}"; do
    LOG_FILE="${LOG_DIR}/image_${IMAGE_NUM}.log"
    migrate_image "$IMAGE_SPEC" "$LOG_FILE" "$IMAGE_NUM" &
    PIDS+=($!)
    IMAGE_NUM=$((IMAGE_NUM + 1))
done

echo -e "${BLUE}   Launched ${#PIDS[@]} parallel migrations${NC}"
echo -e "${YELLOW}   Waiting for all migrations to complete...${NC}"
echo ""

# Wait for all background jobs
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIPPED_COUNT=0

for i in "${!PIDS[@]}"; do
    pid=${PIDS[$i]}
    IMAGE_NUM=$((i + 1))

    if wait $pid; then
        # Check result from log
        LOG_FILE="${LOG_DIR}/image_${IMAGE_NUM}.log"
        if grep -q "SUCCESS" "$LOG_FILE"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        elif grep -q "SKIPPED" "$LOG_FILE"; then
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All parallel migrations completed!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ====================
# 7. SUMMARY
# ====================
echo -e "${YELLOW}[7/7] Migration Summary${NC}"
echo ""
echo -e "${GREEN}✅ Successfully migrated: ${SUCCESS_COUNT}${NC}"
echo -e "${YELLOW}⏭️  Skipped (already exists): ${SKIPPED_COUNT}${NC}"
echo -e "${RED}❌ Failed: ${FAIL_COUNT}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Check logs for details: ${LOG_DIR}${NC}"
    echo ""
fi

# Optional: Display JFrog info
if [ -n "$JFROG_PREFIX" ]; then
    echo -e "${BLUE}📦 Images also accessible via JFrog:${NC}"
    echo -e "   ${JFROG_PREFIX}${TARGET_REGISTRY#*/}"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Verify images: ${BLUE}ibmcloud cr images --restrict ${TARGET_NAMESPACE}${NC}"
echo -e "  2. Update manifests: ${BLUE}./scripts/update-image-refs.sh${NC}"
echo -e "  3. Deploy: ${BLUE}kubectl apply -k kustomize/...${NC}"
echo ""
