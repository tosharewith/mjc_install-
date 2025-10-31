#!/bin/bash
# Mirror images to Artifactory for air-gapped environments
# This script pulls images from source registries and pushes to Artifactory

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/registry-mapping.yaml"

# Registry per namespace (can be overridden via env vars or CLI args)
NAMESPACE="${NAMESPACE:-airflow-test}"
ARTIFACTORY_REGISTRY="${ARTIFACTORY_REGISTRY:-docker-arc3-remote.artifactory.prod.aws.cloud.ihf}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi

    if ! command -v yq &> /dev/null; then
        log_warn "yq is not installed. Install with: brew install yq"
        log_warn "Falling back to manual image list"
        return 1
    fi

    return 0
}

# Function to extract image and tag
parse_image() {
    local full_image="$1"
    local registry=""
    local image=""
    local tag="latest"

    # Split by :
    if [[ "$full_image" =~ : ]]; then
        tag="${full_image##*:}"
        image="${full_image%:*}"
    else
        image="$full_image"
    fi

    echo "$image:$tag"
}

# Function to map source image to target
map_image() {
    local source="$1"

    # Remove source registry prefix and add Artifactory prefix
    # Examples:
    # icr.io/mjc-cr/image:tag → docker-arc3.../image:tag
    # br.icr.io/br-ibm-images/image:tag → docker-arc3.../image:tag
    # docker.io/bitnami/kafka:tag → docker-arc3.../bitnami/kafka:tag
    # milvusdb/milvus:tag → docker-arc3.../milvusdb/milvus:tag

    local image_tag
    image_tag=$(parse_image "$source")
    local image="${image_tag%:*}"
    local tag="${image_tag##*:}"

    # Strip registry prefixes
    image="${image#icr.io/mjc-cr/}"
    image="${image#br.icr.io/br-ibm-images/}"
    image="${image#docker.io/}"
    image="${image#gcr.io/}"
    image="${image#quay.io/}"
    image="${image#icr.io/ext/}"

    echo "${ARTIFACTORY_REGISTRY}/${image}:${tag}"
}

# Function to mirror a single image
mirror_image() {
    local source="$1"
    local target="$2"

    log_info "Mirroring: $source → $target"

    # Pull from source
    log_info "  Pulling $source..."
    if ! docker pull "$source"; then
        log_error "  Failed to pull $source"
        return 1
    fi

    # Tag for target
    log_info "  Tagging as $target..."
    if ! docker tag "$source" "$target"; then
        log_error "  Failed to tag image"
        return 1
    fi

    # Push to target
    log_info "  Pushing to $target..."
    if ! docker push "$target"; then
        log_error "  Failed to push to $target"
        return 1
    fi

    log_info "  ✓ Successfully mirrored"
    return 0
}

# Login to Artifactory
login_artifactory() {
    log_info "Logging in to Artifactory..."

    if [ -z "${ARTIFACTORY_USER:-}" ] || [ -z "${ARTIFACTORY_PASSWORD:-}" ]; then
        log_warn "ARTIFACTORY_USER and ARTIFACTORY_PASSWORD not set"
        log_info "Please enter Artifactory credentials:"
        read -rp "Username: " ARTIFACTORY_USER
        read -rsp "Password: " ARTIFACTORY_PASSWORD
        echo
    fi

    echo "$ARTIFACTORY_PASSWORD" | docker login "$ARTIFACTORY_REGISTRY" \
        --username "$ARTIFACTORY_USER" \
        --password-stdin
}

# Mirror all images from config
mirror_all_images() {
    local failed=0
    local success=0

    # Airflow images
    log_info "=== Mirroring Airflow images ==="
    for source in \
        "icr.io/mjc-cr/mmjc-airflow-service:latest" \
        "quay.io/prometheus/statsd-exporter:v0.28.0"
    do
        target=$(map_image "$source")
        if mirror_image "$source" "$target"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    # Milvus images
    log_info "=== Mirroring Milvus images ==="
    for source in \
        "milvusdb/milvus:v2.5.15" \
        "docker.io/milvusdb/etcd:3.5.18-r1" \
        "docker.io/bitnami/kafka:3.1.0-debian-10-r52" \
        "docker.io/bitnami/zookeeper:3.7.0-debian-10-r320" \
        "minio/minio:RELEASE.2024-05-28T17-19-04Z"
    do
        target=$(map_image "$source")
        if mirror_image "$source" "$target"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    # MMJC custom images
    log_info "=== Mirroring MMJC custom images ==="
    for source in \
        "icr.io/mjc-cr/understanding-agent-arc:1.6.61" \
        "icr.io/mjc-cr/mcp-arc-s3-tool:2.1.17-amd64" \
        "icr.io/mjc-cr/mcp-milvus-db:0.0.1" \
        "icr.io/mjc-cr/mcp-context-forge:0.6.0" \
        "icr.io/mjc-cr/go-mcp-git-s3:1.0.31" \
        "icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64" \
        "icr.io/mjc-cr/mmjc-po:0.0.1" \
        "icr.io/mjc-cr/mmjc-agents:0.0.1" \
        "icr.io/mjc-cr/mmjc-frontend:0.0.1" \
        "icr.io/mjc-cr/api-file-zip-s3:1.0.2" \
        "icr.io/mjc-cr/cos-file-organizer:0.1.0"
    do
        target=$(map_image "$source")
        if mirror_image "$source" "$target"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    # Additional images
    log_info "=== Mirroring additional images ==="
    for source in \
        "langfuse/langfuse:2" \
        "gcr.io/kaniko-project/executor:v1.23.0" \
        "icr.io/ext/istio/proxyv2:1.23.6"
    do
        target=$(map_image "$source")
        if mirror_image "$source" "$target"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    log_info "=== Summary ==="
    log_info "  Success: $success"
    log_error "  Failed: $failed"

    if [ "$failed" -gt 0 ]; then
        return 1
    fi
    return 0
}

# Generate updated Helm values
generate_helm_values() {
    log_info "Generating updated Helm values..."

    cat > "${SCRIPT_DIR}/../helm/airflow-values-artifactory.yaml" <<EOF
# Airflow Helm Values for Air-gapped Environment with Artifactory
# Generated from: scripts/mirror-images-to-artifactory.sh

airflowVersion: "3.0.2"
executor: "CeleryExecutor"

# Artifactory registry
defaultAirflowRepository: ${ARTIFACTORY_REGISTRY}/mmjc-airflow-service
defaultAirflowTag: latest

images:
  airflow:
    pullPolicy: IfNotPresent

  statsd:
    repository: ${ARTIFACTORY_REGISTRY}/prometheus/statsd-exporter
    tag: v0.28.0

# Registry secret for Artifactory
registry:
  secretName: artifactory-registry-secret

# ... rest of configuration same as airflow-values-aws-eks.yaml
EOF

    cat > "${SCRIPT_DIR}/../helm/milvus-values-artifactory.yaml" <<EOF
# Milvus Helm Values for Air-gapped Environment with Artifactory
# Generated from: scripts/mirror-images-to-artifactory.sh

image:
  all:
    repository: ${ARTIFACTORY_REGISTRY}/milvusdb/milvus
    tag: v2.5.15
    pullPolicy: IfNotPresent

# Subchart images
etcd:
  image:
    repository: ${ARTIFACTORY_REGISTRY}/milvusdb/etcd
    tag: 3.5.18-r1

kafka:
  image:
    repository: ${ARTIFACTORY_REGISTRY}/bitnami/kafka
    tag: 3.1.0-debian-10-r52

  zookeeper:
    image:
      repository: ${ARTIFACTORY_REGISTRY}/bitnami/zookeeper
      tag: 3.7.0-debian-10-r320

minio:
  image:
    repository: ${ARTIFACTORY_REGISTRY}/minio/minio
    tag: RELEASE.2024-05-28T17-19-04Z

# ... rest of configuration same as milvus-values-aws-eks.yaml
EOF

    log_info "Generated Helm values:"
    log_info "  - helm/airflow-values-artifactory.yaml"
    log_info "  - helm/milvus-values-artifactory.yaml"
}

# Main
main() {
    log_info "Docker Image Mirror Script for Artifactory"
    log_info "==========================================="

    check_dependencies || true

    # Login to Artifactory
    login_artifactory

    # Mirror images
    if mirror_all_images; then
        log_info "✓ All images mirrored successfully"

        # Generate Helm values
        generate_helm_values

        log_info "✓ Ready for air-gapped installation"
        log_info ""
        log_info "Next steps:"
        log_info "1. Create Artifactory registry secret in Kubernetes"
        log_info "2. Use helm/airflow-values-artifactory.yaml for Airflow"
        log_info "3. Use helm/milvus-values-artifactory.yaml for Milvus"

        exit 0
    else
        log_error "Some images failed to mirror"
        exit 1
    fi
}

# Usage
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<EOF
Usage: $0 [OPTIONS]

Mirror Docker images to Artifactory for air-gapped environments.

Options:
  -n, --namespace NAMESPACE    Target namespace (airflow-test, mmjc-test, etc)
  -r, --registry REGISTRY      Artifactory registry URL
  -h, --help                   Show this help

Environment variables:
  NAMESPACE              - Target namespace (default: airflow-test)
  ARTIFACTORY_REGISTRY   - Artifactory registry URL
  ARTIFACTORY_USER       - Artifactory username
  ARTIFACTORY_PASSWORD   - Artifactory password (or API token)

Examples:
  # Mirror for airflow-test namespace
  ./scripts/mirror-images-to-artifactory.sh --namespace airflow-test

  # Mirror for mmjc-test with custom registry
  NAMESPACE=mmjc-test ARTIFACTORY_REGISTRY=docker-arc4-remote.artifactory.prod.aws.cloud.ihf \\
    ./scripts/mirror-images-to-artifactory.sh

  # With all options
  ./scripts/mirror-images-to-artifactory.sh \\
    --namespace mmjc-test \\
    --registry docker-arc4-remote.artifactory.prod.aws.cloud.ihf
EOF
    exit 0
fi

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--registry)
            ARTIFACTORY_REGISTRY="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main "$@"
