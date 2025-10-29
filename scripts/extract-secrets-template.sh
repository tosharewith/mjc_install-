#!/bin/bash
#
# Script para extrair templates de secrets sem dados sensíveis
# Usage: ./extract-secrets-template.sh <namespace>
#

set -e

NAMESPACE=${1:-"airflow-test"}
OUTPUT_DIR="kustomize/${NAMESPACE}/secrets"

mkdir -p "$OUTPUT_DIR"

echo "🔐 Extraindo templates de secrets do namespace: $NAMESPACE"

# Lista todos os secrets (excluindo service-account-tokens e helm releases)
kubectl get secrets -n "$NAMESPACE" -o json | \
  jq -r '.items[] |
    select(
      .type != "kubernetes.io/service-account-token" and
      (.metadata.name | startswith("sh.helm.release") | not)
    ) |
    {
      apiVersion: .apiVersion,
      kind: .kind,
      metadata: {
        name: .metadata.name,
        namespace: .metadata.namespace,
        labels: .metadata.labels,
        annotations: (.metadata.annotations // {} | with_entries(select(.key | test("^kubectl.kubernetes.io|^helm.sh") | not)))
      },
      type: .type,
      data: (
        .data // {} |
        with_entries(.value = "PLACEHOLDER_BASE64_VALUE_HERE")
      )
    }' > "$OUTPUT_DIR/${NAMESPACE}-secrets-template.yaml"

# Criar arquivo com lista de secrets e suas chaves
echo "📋 Criando lista de secrets e suas chaves..."
kubectl get secrets -n "$NAMESPACE" -o json | \
  jq -r '.items[] |
    select(
      .type != "kubernetes.io/service-account-token" and
      (.metadata.name | startswith("sh.helm.release") | not)
    ) |
    {
      name: .metadata.name,
      type: .type,
      keys: (.data // {} | keys)
    }' | jq -s '.' > "$OUTPUT_DIR/${NAMESPACE}-secrets-keys.json"

echo "✅ Templates de secrets criados em: $OUTPUT_DIR"
echo "   - ${NAMESPACE}-secrets-template.yaml (template com placeholders)"
echo "   - ${NAMESPACE}-secrets-keys.json (lista de chaves por secret)"
