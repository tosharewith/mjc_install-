#!/bin/bash
#
# Script para separar recursos Kubernetes por tipo
# Usage: ./split-k8s-resources.sh <input-file> <output-dir>
#

set -e

INPUT_FILE="$1"
OUTPUT_DIR="$2"

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <input-file> <output-dir>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "📦 Separando recursos de: $INPUT_FILE"

# Função para limpar metadata desnecessária
clean_metadata() {
    jq 'del(
        .metadata.uid,
        .metadata.resourceVersion,
        .metadata.generation,
        .metadata.creationTimestamp,
        .metadata.managedFields,
        .metadata.selfLink,
        .status,
        .metadata.ownerReferences
    ) |
    if .metadata.annotations then
        .metadata.annotations |= with_entries(
            select(.key | test("^(kubectl.kubernetes.io|cni.projectcalico.org|checksum/)") | not)
        )
    else . end'
}

# Extrair Deployments
echo "  → Extraindo Deployments..."
kubectl get -f "$INPUT_FILE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.kind == "Deployment")' | \
    clean_metadata | \
    jq -s '{"apiVersion": "v1", "kind": "List", "items": .}' \
    > "$OUTPUT_DIR/deployments.yaml"

# Extrair StatefulSets
echo "  → Extraindo StatefulSets..."
kubectl get -f "$INPUT_FILE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.kind == "StatefulSet")' | \
    clean_metadata | \
    jq -s '{"apiVersion": "v1", "kind": "List", "items": .}' \
    > "$OUTPUT_DIR/statefulsets.yaml"

# Extrair Services
echo "  → Extraindo Services..."
kubectl get -f "$INPUT_FILE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.kind == "Service")' | \
    clean_metadata | \
    jq 'del(.spec.clusterIP, .spec.clusterIPs)' | \
    jq -s '{"apiVersion": "v1", "kind": "List", "items": .}' \
    > "$OUTPUT_DIR/services.yaml"

# Extrair ConfigMaps (excluindo system configmaps)
echo "  → Extraindo ConfigMaps..."
kubectl get -f "$INPUT_FILE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.kind == "ConfigMap" and (.metadata.name | test("^(kube-root-ca|istio-)") | not))' | \
    clean_metadata | \
    jq -s '{"apiVersion": "v1", "kind": "List", "items": .}' \
    > "$OUTPUT_DIR/configmaps.yaml"

# Extrair PVCs
echo "  → Extraindo PVCs..."
kubectl get -f "$INPUT_FILE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.kind == "PersistentVolumeClaim")' | \
    clean_metadata | \
    jq -s '{"apiVersion": "v1", "kind": "List", "items": .}' \
    > "$OUTPUT_DIR/pvcs.yaml" 2>/dev/null || echo "    (nenhum PVC encontrado)"

echo "✅ Recursos separados em: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.yaml
