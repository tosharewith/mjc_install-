#!/bin/bash
#
# Pull and Retag Images for Air-Gapped Installation
# This script pulls all images from IBM Cloud Container Registry (ICR)
# and retags them for Artifactory (br.icr.io/br-ibm-images)
#
# Usage: ./pull-and-retag-images.sh [--push]
#   --push: Actually push to br.icr.io (requires authentication)
#   --dry-run: Only show what would be done (default)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_REGISTRY="icr.io/mjc-cr"
TARGET_REGISTRY="br.icr.io/br-ibm-images"
DRY_RUN=true

# Parse arguments
if [[ "$1" == "--push" ]]; then
    DRY_RUN=false
    echo -e "${YELLOW}⚠️  PUSH MODE ENABLED - Images will be pushed to Artifactory${NC}"
elif [[ "$1" == "--dry-run" ]] || [[ -z "$1" ]]; then
    DRY_RUN=true
    echo -e "${BLUE}ℹ️  DRY RUN MODE - No images will be pushed${NC}"
else
    echo "Usage: $0 [--push|--dry-run]"
    exit 1
fi

echo ""
echo "=========================================="
echo "Image Pull and Retag Script"
echo "=========================================="
echo "Source: $SOURCE_REGISTRY"
echo "Target: $TARGET_REGISTRY"
echo "=========================================="
echo ""

# Image manifest based on mmjc-test namespace (verified 2025-12-27)
# Format: "image-name:tag"
declare -a IMAGES=(
    # MMJC Custom Applications
    "mmjc-agents:0.0.2"
    "mmjc-frontend:0.0.2"
    "mmjc-po:0.0.2"
    "mojoco-entities-manager:0.0.2"

    # MCP Servers
    "go-mcp-git-s3:1.0.31"
    "mcp-milvus-db:0.0.2"
    "mcp-context-forge:0.9.0"
    "arc-spring-api:3.1.2-amd64"

    # Validators
    "mjc-mermaid-validator:1.0.17-llm-ready-amd64"
)

# Public images that need to be mirrored
declare -a PUBLIC_IMAGES=(
    # Milvus
    "milvusdb/milvus:v2.5.15"
    "zilliz/attu:v2.5.6"
    "docker.io/milvusdb/etcd:3.5.18-r1"

    # Kafka/Zookeeper (these exact tags no longer available on Docker Hub)
    # If you need these, export them directly from your cluster using:
    #   kubectl get pods -n mmjc-test -o jsonpath='{.items[*].spec.containers[*].image}' | grep kafka
    # "docker.io/bitnami/kafka:3.1.0-debian-10-r52"
    # "docker.io/bitnami/zookeeper:3.7.0-debian-10-r320"

    # MinIO
    "minio/minio:RELEASE.2024-05-28T17-19-04Z"

    # Redis
    "redis:8.0.2"

    # Airflow dependencies
    "quay.io/prometheus/statsd-exporter:v0.28.0"
)

# Counters
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# Function to pull, tag, and optionally push an image
process_image() {
    local source_image=$1
    local target_image=$2
    local image_name=$(basename $source_image | cut -d: -f1)

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Processing: ${image_name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    TOTAL=$((TOTAL + 1))

    # Check if image already exists locally
    if docker image inspect "$source_image" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Image already exists locally: $source_image${NC}"
        echo -e "   Skipping pull, will retag..."
    else
        echo -e "   ${BLUE}→${NC} Pulling: ${source_image}"
        if docker pull "$source_image"; then
            echo -e "   ${GREEN}✓${NC} Pull successful"
        else
            echo -e "   ${RED}✗${NC} Pull failed"
            FAILED=$((FAILED + 1))
            return 1
        fi
    fi

    echo -e "   ${BLUE}→${NC} Tagging: ${target_image}"
    if docker tag "$source_image" "$target_image"; then
        echo -e "   ${GREEN}✓${NC} Tag successful"
    else
        echo -e "   ${RED}✗${NC} Tag failed"
        FAILED=$((FAILED + 1))
        return 1
    fi

    if [[ "$DRY_RUN" == false ]]; then
        echo -e "   ${BLUE}→${NC} Pushing: ${target_image}"
        if docker push "$target_image"; then
            echo -e "   ${GREEN}✓${NC} Push successful"
            SUCCESS=$((SUCCESS + 1))
        else
            echo -e "   ${RED}✗${NC} Push failed"
            FAILED=$((FAILED + 1))
            return 1
        fi
    else
        echo -e "   ${YELLOW}⊘${NC} Push skipped (dry-run mode)"
        SKIPPED=$((SKIPPED + 1))
    fi

    return 0
}

# Main processing
echo -e "${GREEN}Processing Custom ICR Images...${NC}"
echo ""

for image in "${IMAGES[@]}"; do
    source_image="${SOURCE_REGISTRY}/${image}"
    target_image="${TARGET_REGISTRY}/${image}"
    process_image "$source_image" "$target_image" || true
done

echo ""
echo -e "${GREEN}Processing Public Images...${NC}"
echo ""

for image in "${PUBLIC_IMAGES[@]}"; do
    # For public images, extract just the image name without registry
    image_name=$(echo "$image" | sed 's|^docker.io/||' | sed 's|^quay.io/||')
    base_name=$(basename "$image_name")
    target_image="${TARGET_REGISTRY}/${base_name}"

    process_image "$image" "$target_image" || true
done

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}Summary${NC}"
echo "=========================================="
echo -e "Total images processed: ${TOTAL}"
if [[ "$DRY_RUN" == false ]]; then
    echo -e "${GREEN}Successfully pushed: ${SUCCESS}${NC}"
    echo -e "${RED}Failed: ${FAILED}${NC}"
else
    echo -e "${YELLOW}Tagged (not pushed): ${SKIPPED}${NC}"
    echo -e "${RED}Failed: ${FAILED}${NC}"
fi
echo "=========================================="

# Docker images list
echo ""
echo "Local images tagged for Artifactory:"
docker images "${TARGET_REGISTRY}/*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}⚠️  This was a DRY RUN${NC}"
    echo "To actually push images to Artifactory, run:"
    echo -e "  ${BLUE}$0 --push${NC}"
    echo ""
    echo "Before pushing, make sure you're logged in to Artifactory:"
    echo -e "  ${BLUE}docker login br.icr.io${NC}"
else
    echo -e "${GREEN}✓ Images have been pushed to Artifactory${NC}"
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Verify images in Artifactory:"
echo "   curl -u user:pass https://br.icr.io/v2/_catalog"
echo ""
echo "2. Test deployment with Artifactory overlay:"
echo "   kubectl apply -k kustomize/overlays/artifactory --dry-run=client"
echo ""
echo "3. Deploy to air-gapped environment:"
echo "   kubectl apply -k kustomize/overlays/artifactory"
echo "=========================================="

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
