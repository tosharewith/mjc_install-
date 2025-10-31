#!/bin/bash

# Validation script for kustomize configurations
# Checks for common issues and validates YAML syntax

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Kustomize Configuration Validation ==="
echo ""

# Function to validate a kustomize directory
validate_kustomize() {
    local dir=$1
    local name=$(basename "$dir")
    
    echo "Validating: $name"
    echo "-----------------------------------"
    
    # Check if kustomization.yaml exists
    if [ ! -f "$dir/kustomization.yaml" ]; then
        echo -e "${RED}✗ kustomization.yaml not found${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ kustomization.yaml found${NC}"
    
    # Validate kustomize build
    if kubectl kustomize "$dir" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Kustomize build successful${NC}"
    else
        echo -e "${RED}✗ Kustomize build failed${NC}"
        kubectl kustomize "$dir" 2>&1 || true
        return 1
    fi
    
    # Count resources
    local resource_count=$(kubectl kustomize "$dir" 2>/dev/null | grep -c "^kind:" || echo "0")
    echo -e "${GREEN}✓ Resources generated: $resource_count${NC}"
    
    # Validate with dry-run
    if kubectl apply -k "$dir" --dry-run=client -o yaml > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Dry-run validation passed${NC}"
    else
        echo -e "${YELLOW}⚠ Dry-run validation warnings:${NC}"
        kubectl apply -k "$dir" --dry-run=client 2>&1 || true
    fi
    
    # Check for images
    local image_count=$(kubectl kustomize "$dir" 2>/dev/null | grep "image:" | wc -l)
    echo -e "${GREEN}✓ Images found: $image_count${NC}"
    
    echo ""
}

# Validate base directories
for dir in airflow-test mmjc-test; do
    if [ -d "$dir" ]; then
        validate_kustomize "$dir"
    fi
done

# Validate overlays if they exist
if [ -d "overlays" ]; then
    echo "=== Validating Overlays ==="
    echo ""
    for overlay in overlays/*/; do
        if [ -f "${overlay}kustomization.yaml" ]; then
            validate_kustomize "$overlay"
        fi
    done
fi

echo "=== Validation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Review the generated resources: kubectl kustomize airflow-test/"
echo "  2. Check images: kubectl kustomize airflow-test/ | grep 'image:'"
echo "  3. Apply to cluster: kubectl apply -k airflow-test/"
