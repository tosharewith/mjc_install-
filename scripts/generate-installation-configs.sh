#!/bin/bash
#
# Generate Installation-Specific Configurations
# This script takes a values file and generates Kubernetes manifests
# with installation-specific values substituted
#
# Usage: ./generate-installation-configs.sh <values-file> <output-dir>
#   Example: ./generate-installation-configs.sh installation-values-prod.yaml ./output/prod/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check dependencies
command -v yq >/dev/null 2>&1 || {
    echo -e "${RED}Error: yq is required but not installed.${NC}"
    echo "Install with: brew install yq"
    exit 1
}

# Parse arguments
VALUES_FILE="${1:-installation-values.yaml}"
OUTPUT_DIR="${2:-./generated-configs}"

if [[ ! -f "$VALUES_FILE" ]]; then
    echo -e "${RED}Error: Values file not found: $VALUES_FILE${NC}"
    echo ""
    echo "Usage: $0 <values-file> [output-dir]"
    echo ""
    echo "Example:"
    echo "  1. Copy the template:"
    echo "     cp kustomize/base/common-config/installation-values-template.yaml my-installation.yaml"
    echo ""
    echo "  2. Edit with your values:"
    echo "     vi my-installation.yaml"
    echo ""
    echo "  3. Generate configs:"
    echo "     $0 my-installation.yaml ./generated"
    exit 1
fi

echo ""
echo "=========================================="
echo "Configuration Generator"
echo "=========================================="
echo -e "${BLUE}Values file:${NC} $VALUES_FILE"
echo -e "${BLUE}Output dir:${NC} $OUTPUT_DIR"
echo "=========================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Read values from YAML file
echo -e "${GREEN}→ Reading installation values...${NC}"

# Extract values using yq (works with both mikefarah/yq and python yq)
INSTALLATION_NAME=$(yq -r '.installation.name' "$VALUES_FILE" 2>/dev/null || yq eval '.installation.name' "$VALUES_FILE")
ENVIRONMENT=$(yq -r '.installation.environment' "$VALUES_FILE" 2>/dev/null || yq eval '.installation.environment' "$VALUES_FILE")
CLOUD_PROVIDER=$(yq -r '.installation.cloud_provider' "$VALUES_FILE" 2>/dev/null || yq eval '.installation.cloud_provider' "$VALUES_FILE")

DB_HOST=$(yq -r '.database.host' "$VALUES_FILE" 2>/dev/null || yq eval '.database.host' "$VALUES_FILE")
DB_PORT=$(yq -r '.database.port' "$VALUES_FILE" 2>/dev/null || yq eval '.database.port' "$VALUES_FILE")
DB_NAME=$(yq -r '.database.name' "$VALUES_FILE" 2>/dev/null || yq eval '.database.name' "$VALUES_FILE")
DB_SSL_MODE=$(yq -r '.database.ssl_mode' "$VALUES_FILE" 2>/dev/null || yq eval '.database.ssl_mode' "$VALUES_FILE")

S3_ENDPOINT=$(yq -r '.object_storage.endpoint' "$VALUES_FILE" 2>/dev/null || yq eval '.object_storage.endpoint' "$VALUES_FILE")
S3_REGION=$(yq -r '.object_storage.region' "$VALUES_FILE" 2>/dev/null || yq eval '.object_storage.region' "$VALUES_FILE")

LLM_GATEWAY_URL=$(yq -r '.llm.gateway_url' "$VALUES_FILE" 2>/dev/null || yq eval '.llm.gateway_url' "$VALUES_FILE")
MODEL_NAME=$(yq -r '.llm.default_model' "$VALUES_FILE" 2>/dev/null || yq eval '.llm.default_model' "$VALUES_FILE")

MCP_SERVER_ID=$(yq -r '.mcp.gateway.server_id' "$VALUES_FILE" 2>/dev/null || yq eval '.mcp.gateway.server_id' "$VALUES_FILE")

GIT_USER=$(yq -r '.git.username' "$VALUES_FILE" 2>/dev/null || yq eval '.git.username' "$VALUES_FILE")
GIT_REPO_URL=$(yq -r '.git.default_repo' "$VALUES_FILE" 2>/dev/null || yq eval '.git.default_repo' "$VALUES_FILE")

MMJC_NAMESPACE=$(yq -r '.kubernetes.namespace.mmjc' "$VALUES_FILE" 2>/dev/null || yq eval '.kubernetes.namespace.mmjc' "$VALUES_FILE")
AIRFLOW_NAMESPACE=$(yq -r '.kubernetes.namespace.airflow' "$VALUES_FILE" 2>/dev/null || yq eval '.kubernetes.namespace.airflow' "$VALUES_FILE")
IMAGE_REGISTRY=$(yq -r '.kubernetes.image_registry' "$VALUES_FILE" 2>/dev/null || yq eval '.kubernetes.image_registry' "$VALUES_FILE")

echo -e "  ${GREEN}✓${NC} Installation: $INSTALLATION_NAME ($ENVIRONMENT)"
echo -e "  ${GREEN}✓${NC} Cloud: $CLOUD_PROVIDER"
echo -e "  ${GREEN}✓${NC} Namespaces: $MMJC_NAMESPACE, $AIRFLOW_NAMESPACE"
echo -e "  ${GREEN}✓${NC} Registry: $IMAGE_REGISTRY"
echo ""

# Create ConfigMap with installation values
echo -e "${GREEN}→ Generating installation ConfigMap...${NC}"

cat > "$OUTPUT_DIR/installation-config.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: installation-config
  namespace: $MMJC_NAMESPACE
  labels:
    installation: $INSTALLATION_NAME
    environment: $ENVIRONMENT
data:
  # Installation metadata
  INSTALLATION_NAME: "$INSTALLATION_NAME"
  ENVIRONMENT: "$ENVIRONMENT"
  CLOUD_PROVIDER: "$CLOUD_PROVIDER"

  # Database configuration
  POSTGRESQL_HOST: "$DB_HOST"
  POSTGRESQL_PORT: "$DB_PORT"
  POSTGRESQL_DATABASE: "$DB_NAME"
  POSTGRESQL_SSLMODE: "$DB_SSL_MODE"

  # Object storage
  COS_ENDPOINT_URL: "$S3_ENDPOINT"
  S3_ENDPOINT: "$S3_ENDPOINT"
  S3_REGION: "$S3_REGION"

  # LLM configuration
  OPENAI_API_BASE: "$LLM_GATEWAY_URL"
  MODEL_NAME: "$MODEL_NAME"

  # MCP configuration
  MCP_GATEWAY_URL: "http://mcp-gateway-$ENVIRONMENT.$MMJC_NAMESPACE.svc.cluster.local/servers/$MCP_SERVER_ID/sse"

  # Git configuration
  GIT_USERNAME: "$GIT_USER"
  GIT_REPO_BASE: "$GIT_REPO_URL"

  # Service URLs
  MERMAID_VALIDATOR_URL: "http://mermaid-validator-api.$MMJC_NAMESPACE.svc.cluster.local/api/v1/validate"
  MILVUS_HOST: "milvus-mmjc-$ENVIRONMENT-proxy.$MMJC_NAMESPACE.svc.cluster.local"
  REDIS_HOST: "redis-cluster-$ENVIRONMENT.$MMJC_NAMESPACE.svc.cluster.local"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: installation-config
  namespace: $AIRFLOW_NAMESPACE
  labels:
    installation: $INSTALLATION_NAME
    environment: $ENVIRONMENT
data:
  # Installation metadata
  INSTALLATION_NAME: "$INSTALLATION_NAME"
  ENVIRONMENT: "$ENVIRONMENT"
  CLOUD_PROVIDER: "$CLOUD_PROVIDER"

  # Database configuration
  POSTGRESQL_HOST: "$DB_HOST"
  POSTGRESQL_PORT: "$DB_PORT"
  POSTGRESQL_DATABASE: "$DB_NAME"

  # Object storage
  S3_ENDPOINT: "$S3_ENDPOINT"
  S3_REGION: "$S3_REGION"
EOF

echo -e "  ${GREEN}✓${NC} Created: $OUTPUT_DIR/installation-config.yaml"

# Create kustomization overlay
echo ""
echo -e "${GREEN}→ Generating kustomization overlay...${NC}"

mkdir -p "$OUTPUT_DIR/overlay"

cat > "$OUTPUT_DIR/overlay/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Installation: $INSTALLATION_NAME ($ENVIRONMENT)
# Generated: $(date)

bases:
  - ../../kustomize/mmjc-test
  - ../../kustomize/airflow-test

namespace: $MMJC_NAMESPACE

# Add installation config
resources:
  - ../installation-config.yaml

# Override images with installation-specific registry
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: $IMAGE_REGISTRY/mmjc-agents
    newTag: 0.0.2

  - name: icr.io/mjc-cr/mmjc-frontend
    newName: $IMAGE_REGISTRY/mmjc-frontend
    newTag: 0.0.2

  - name: icr.io/mjc-cr/mmjc-po
    newName: $IMAGE_REGISTRY/mmjc-po
    newTag: 0.0.2

  - name: icr.io/mjc-cr/go-mcp-git-s3
    newName: $IMAGE_REGISTRY/go-mcp-git-s3
    newTag: 1.0.31

  - name: icr.io/mjc-cr/mcp-milvus-db
    newName: $IMAGE_REGISTRY/mcp-milvus-db
    newTag: 0.0.2

  - name: icr.io/mjc-cr/mcp-context-forge
    newName: $IMAGE_REGISTRY/mcp-context-forge
    newTag: 0.8.0

  - name: icr.io/mjc-cr/mcp-arc-s3-server
    newName: $IMAGE_REGISTRY/mcp-arc-s3-server
    newTag: 2.1.45-amd64

  - name: icr.io/mjc-cr/mjc-mermaid-validator
    newName: $IMAGE_REGISTRY/mjc-mermaid-validator
    newTag: 1.0.17-llm-ready-amd64

  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: $IMAGE_REGISTRY/mmjc-airflow-service
    newTag: 3.0.2

commonLabels:
  installation: $INSTALLATION_NAME
  environment: $ENVIRONMENT
  cloud: $CLOUD_PROVIDER
EOF

echo -e "  ${GREEN}✓${NC} Created: $OUTPUT_DIR/overlay/kustomization.yaml"

# Test kustomization build
echo ""
echo -e "${GREEN}→ Testing kustomization build...${NC}"

if kubectl kustomize "$OUTPUT_DIR/overlay" > "$OUTPUT_DIR/generated-manifests.yaml" 2>&1; then
    MANIFEST_COUNT=$(grep -c "^kind:" "$OUTPUT_DIR/generated-manifests.yaml" || true)
    echo -e "  ${GREEN}✓${NC} Build successful: $MANIFEST_COUNT Kubernetes resources"
    echo -e "  ${GREEN}✓${NC} Output: $OUTPUT_DIR/generated-manifests.yaml"
else
    echo -e "  ${RED}✗${NC} Build failed - check kustomization syntax"
    exit 1
fi

# Generate secrets template
echo ""
echo -e "${GREEN}→ Generating secrets template...${NC}"

cat > "$OUTPUT_DIR/secrets-template.yaml" << 'EOF'
# SECRETS TEMPLATE
# Fill in base64-encoded values for your installation
# DO NOT commit this file with real secrets!
#
# To encode a value: echo -n "your-value" | base64
# To decode a value: echo "base64-value" | base64 -d

---
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret-ENVIRONMENT
  namespace: NAMESPACE
type: Opaque
data:
  POSTGRESQL_USERNAME: "BASE64_ENCODED_USERNAME"
  POSTGRESQL_PASSWORD: "BASE64_ENCODED_PASSWORD"

---
apiVersion: v1
kind: Secret
metadata:
  name: s3-access-key-tools
  namespace: NAMESPACE
type: Opaque
data:
  S3_ACCESS_KEY: "BASE64_ENCODED_ACCESS_KEY"
  S3_SECRET_KEY: "BASE64_ENCODED_SECRET_KEY"

---
apiVersion: v1
kind: Secret
metadata:
  name: openai-api-key-agents
  namespace: NAMESPACE
type: Opaque
data:
  OPENAI_API_KEY: "BASE64_ENCODED_API_KEY"

---
apiVersion: v1
kind: Secret
metadata:
  name: mcp-gateway-jwt-token
  namespace: NAMESPACE
type: Opaque
data:
  jwt_token: "BASE64_ENCODED_JWT_TOKEN"

---
apiVersion: v1
kind: Secret
metadata:
  name: git-password-secret-agents
  namespace: NAMESPACE
type: Opaque
data:
  GIT_PASSWORD_SECRET: "BASE64_ENCODED_GIT_TOKEN"

---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-test-fernet-key
  namespace: AIRFLOW_NAMESPACE
type: Opaque
data:
  fernet-key: "BASE64_ENCODED_FERNET_KEY"

# Generate Fernet key with:
# python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
EOF

echo -e "  ${GREEN}✓${NC} Created: $OUTPUT_DIR/secrets-template.yaml"
echo -e "  ${YELLOW}⚠️  Remember to fill in actual base64-encoded values!${NC}"

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}✓ Configuration Generation Complete${NC}"
echo "=========================================="
echo ""
echo "Generated files:"
echo "  1. $OUTPUT_DIR/installation-config.yaml"
echo "  2. $OUTPUT_DIR/overlay/kustomization.yaml"
echo "  3. $OUTPUT_DIR/generated-manifests.yaml"
echo "  4. $OUTPUT_DIR/secrets-template.yaml"
echo ""
echo "Next steps:"
echo "  1. Review generated files"
echo "  2. Fill in secrets-template.yaml with real values"
echo "  3. Deploy:"
echo "     kubectl apply -f $OUTPUT_DIR/installation-config.yaml"
echo "     kubectl apply -f $OUTPUT_DIR/secrets-template.yaml  # After filling values"
echo "     kubectl apply -k $OUTPUT_DIR/overlay"
echo ""
echo "Or use the full manifest:"
echo "     kubectl apply -f $OUTPUT_DIR/generated-manifests.yaml"
echo "=========================================="
