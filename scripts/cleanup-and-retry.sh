#!/bin/bash
# 🧹 Cleanup old images and retry migration
# Created: 2025-10-30

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧹 Cleanup and Retry Migration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ====================
# 1. SET REGION
# ====================
echo -e "${YELLOW}[1/5] Setting region to Brazil...${NC}"
ibmcloud cr region-set br.icr.io
echo ""

# ====================
# 2. CHECK CURRENT QUOTA
# ====================
echo -e "${YELLOW}[2/5] Checking current quota...${NC}"
ibmcloud cr quota
echo ""

# ====================
# 3. DELETE OLD IMAGES
# ====================
echo -e "${YELLOW}[3/5] Deleting old images to free up space...${NC}"

echo -e "${BLUE}   Deleting: java-mcp-s3-git-tools:1.0.0-amd64 (181 MB)${NC}"
if ibmcloud cr image-rm br.icr.io/br-ibm-images/java-mcp-s3-git-tools:1.0.0-amd64 --force 2>/dev/null; then
    echo -e "${GREEN}   ✅ Deleted${NC}"
else
    echo -e "${YELLOW}   ⚠️  Already deleted or not found${NC}"
fi

echo -e "${BLUE}   Deleting: mjc-mermaid-validator:1.0.17 (68 MB - duplicate)${NC}"
if ibmcloud cr image-rm br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17 --force 2>/dev/null; then
    echo -e "${GREEN}   ✅ Deleted${NC}"
else
    echo -e "${YELLOW}   ⚠️  Already deleted or not found${NC}"
fi

echo ""
echo -e "${GREEN}   Expected space freed: ~249 MB${NC}"
echo ""

# ====================
# 4. VERIFY NEW QUOTA
# ====================
echo -e "${YELLOW}[4/5] Verifying new quota...${NC}"
ibmcloud cr quota
echo ""

# ====================
# 5. RE-RUN MIGRATION
# ====================
echo -e "${YELLOW}[5/5] Re-running migration...${NC}"
echo ""

cd "$(dirname "$0")/.."

if [ -f "./scripts/migrate-images-parallel.sh" ]; then
    echo -e "${BLUE}   Running parallel migration script...${NC}"
    ./scripts/migrate-images-parallel.sh
else
    echo -e "${RED}   ❌ Migration script not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Cleanup and Migration Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Verify results:${NC}"
echo -e "  ${BLUE}ibmcloud cr images --restrict br-ibm-images${NC}"
echo ""
