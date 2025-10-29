#!/bin/bash
# 🔄 Update Image References in Kustomization Files
# After migrating images, update all references
# Created: 2025-10-29

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔄 Update Image References${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Source config
if [ -f "config/migration.env" ]; then
    source config/migration.env
else
    echo -e "${YELLOW}⚠️  No migration.env found, using defaults${NC}"
fi

# Get target registry - Default to Brazil region
TARGET_ICR_REGION=${TARGET_ICR_REGION:-"br.icr.io"}
TARGET_NAMESPACE=${TARGET_NAMESPACE:-"br-ibm-images"}
DEFAULT_TARGET="${TARGET_ICR_REGION}/${TARGET_NAMESPACE}"
TARGET_REGISTRY=${TARGET_REGISTRY:-$DEFAULT_TARGET}

# Optional JFrog prefix
JFROG_PREFIX=${JFROG_PREFIX:-""}

echo -e "${BLUE}Target Registry:${NC} ${TARGET_REGISTRY}"
echo ""

# ====================
# UPDATE AIRFLOW KUSTOMIZATION
# ====================
echo -e "${YELLOW}[1/2] Updating Airflow kustomization...${NC}"

AIRFLOW_KUSTOMIZATION="kustomize/airflow-test/kustomization.yaml"

if [ ! -f "$AIRFLOW_KUSTOMIZATION" ]; then
    echo -e "${YELLOW}⚠️  Airflow kustomization not found, skipping${NC}"
else
    # Check if images section exists
    if grep -q "^images:" "$AIRFLOW_KUSTOMIZATION"; then
        echo -e "${YELLOW}   Images section already exists, updating...${NC}"
        # You can use sed or manual edit here
    else
        echo -e "${YELLOW}   Adding images section...${NC}"

        # Add images section
        cat >> "$AIRFLOW_KUSTOMIZATION" << EOF

# Image overrides for migration to ${TARGET_REGISTRY}
# Source: icr.io/mjc-cr (GLOBAL region)
# Public images (milvus, kafka, etc.) kept in original registries due to licensing
images:
  # Airflow service
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: ${TARGET_REGISTRY}/mmjc-airflow-service
    newTag: latest
  # Public images - NOT migrated, use from original registries
  # - quay.io/prometheus/statsd-exporter:v0.28.0 (stays in quay.io)
EOF
    fi

    echo -e "${GREEN}   ✅ Updated ${AIRFLOW_KUSTOMIZATION}${NC}"
fi
echo ""

# ====================
# UPDATE MILVUS KUSTOMIZATION
# ====================
echo -e "${YELLOW}[2/2] Updating Milvus kustomization...${NC}"

# Check if milvus kustomization exists
MILVUS_KUSTOMIZATION="kustomize/milvus/kustomization.yaml"

if [ ! -f "$MILVUS_KUSTOMIZATION" ]; then
    # Maybe it's in milvus-dev folder
    MILVUS_KUSTOMIZATION="kustomize/milvus-dev/kustomization.yaml"
fi

if [ ! -f "$MILVUS_KUSTOMIZATION" ]; then
    echo -e "${YELLOW}⚠️  Milvus kustomization not found${NC}"
    echo -e "${YELLOW}   You'll need to manually update the milvus deployment files${NC}"
else
    # Check if images section exists
    if grep -q "^images:" "$MILVUS_KUSTOMIZATION"; then
        echo -e "${YELLOW}   Images section already exists${NC}"
    else
        echo -e "${YELLOW}   Adding images section...${NC}"

        # Add images section
        cat >> "$MILVUS_KUSTOMIZATION" << EOF

# Image overrides for migration to ${TARGET_REGISTRY}
# Source: icr.io/mjc-cr (GLOBAL region)
# Public images (milvus, kafka, etc.) kept in original registries due to licensing
images:
  # MCP Services
  - name: icr.io/mjc-cr/mcp-arc-s3-tool
    newName: ${TARGET_REGISTRY}/mcp-arc-s3-tool
    newTag: 2.1.17-amd64
  - name: icr.io/mjc-cr/mcp-milvus-db
    newName: ${TARGET_REGISTRY}/mcp-milvus-db
    newTag: 0.0.1

  # Validators
  - name: icr.io/mjc-cr/mjc-mermaid-validator
    newName: ${TARGET_REGISTRY}/mjc-mermaid-validator
    newTag: 1.0.17-llm-ready-amd64

  # MMJC Services
  - name: icr.io/mjc-cr/mmjc-po
    newName: ${TARGET_REGISTRY}/mmjc-po
    newTag: 0.0.1

  # Understanding Agent
  - name: icr.io/mjc-cr/understanding-agent-arc
    newName: ${TARGET_REGISTRY}/understanding-agent-arc
    # Note: Multiple versions (1.5.5 and v1.6.57) - update tags as needed

  # Public images - NOT migrated, use from original registries
  # - milvusdb/milvus:v2.5.15 (stays in docker.io)
  # - docker.io/milvusdb/etcd:3.5.18-r1 (stays in docker.io)
  # - docker.io/bitnami/kafka:3.1.0-debian-10-r52 (stays in docker.io)
  # - docker.io/bitnami/zookeeper:3.7.0-debian-10-r320 (stays in docker.io)
EOF
    fi

    echo -e "${GREEN}   ✅ Updated ${MILVUS_KUSTOMIZATION}${NC}"
fi
echo ""

# ====================
# SUMMARY
# ====================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Image references updated!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review changes: ${BLUE}git diff${NC}"
echo -e "  2. Test build: ${BLUE}kubectl kustomize kustomize/airflow-test${NC}"
echo -e "  3. Deploy: ${BLUE}kubectl apply -k kustomize/airflow-test${NC}"
echo ""
