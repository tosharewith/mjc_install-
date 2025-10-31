#!/bin/bash

# Helper script to change image registry prefix for all images in kustomize manifests
# Usage: ./change-image-registry.sh <namespace> <old-prefix> <new-prefix>

set -e

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <namespace> <old-prefix> <new-prefix>"
    echo ""
    echo "Examples:"
    echo "  $0 mmjc-test icr.io/mjc-cr br.icr.io/br-ibm-images"
    echo "  $0 airflow-test icr.io/mjc-cr private-registry.company.com/images"
    echo ""
    exit 1
fi

NAMESPACE=$1
OLD_PREFIX=$2
NEW_PREFIX=$3
KUSTOMIZATION_FILE="$NAMESPACE/kustomization.yaml"

if [ ! -f "$KUSTOMIZATION_FILE" ]; then
    echo "Error: $KUSTOMIZATION_FILE not found"
    exit 1
fi

echo "Changing image registry prefix in $KUSTOMIZATION_FILE"
echo "  From: $OLD_PREFIX"
echo "  To:   $NEW_PREFIX"
echo ""

# Create backup
cp "$KUSTOMIZATION_FILE" "${KUSTOMIZATION_FILE}.backup"
echo "Backup created: ${KUSTOMIZATION_FILE}.backup"

# Replace the prefix in the images section
# Use perl for more reliable regex replacement
perl -i -pe "s|newName: ${OLD_PREFIX}/|newName: ${NEW_PREFIX}/|g" "$KUSTOMIZATION_FILE"

echo "✓ Image registry prefix updated successfully"
echo ""
echo "Preview changes:"
git diff --no-index "${KUSTOMIZATION_FILE}.backup" "$KUSTOMIZATION_FILE" || true
echo ""
echo "To verify the changes, run:"
echo "  kubectl kustomize $NAMESPACE/ | grep 'image:'"
echo ""
echo "To apply the changes, run:"
echo "  kubectl apply -k $NAMESPACE/"
echo ""
echo "To restore the backup, run:"
echo "  mv ${KUSTOMIZATION_FILE}.backup $KUSTOMIZATION_FILE"
