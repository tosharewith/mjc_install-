#!/bin/bash

# Script to extract all Kubernetes resources from specified namespaces

set -e

NAMESPACES=("airflow-test" "mmjc-test" "mmjc-dev")
OUTPUT_BASE_DIR="originals"

# Resource types to extract
RESOURCE_TYPES=(
    "deployments"
    "statefulsets"
    "daemonsets"
    "services"
    "configmaps"
    "secrets"
    "persistentvolumeclaims"
    "ingresses"
    "networkpolicies"
    "serviceaccounts"
    "roles"
    "rolebindings"
    "horizontalpodautoscalers"
    "jobs"
    "cronjobs"
)

echo "=== Extracting Kubernetes Resources ==="
echo ""

for ns in "${NAMESPACES[@]}"; do
    echo "Processing namespace: $ns"
    echo "-----------------------------------"
    
    # Create output directory
    OUTPUT_DIR="${OUTPUT_BASE_DIR}/${ns}"
    
    for resource_type in "${RESOURCE_TYPES[@]}"; do
        # Get resource names
        resources=$(kubectl get "$resource_type" -n "$ns" -o name 2>/dev/null || echo "")
        
        if [ -z "$resources" ]; then
            continue
        fi
        
        count=$(echo "$resources" | wc -l)
        echo "  Extracting $count $resource_type..."
        
        # Create subdirectory based on resource type
        case $resource_type in
            persistentvolumeclaims)
                subdir="pvcs"
                ;;
            horizontalpodautoscalers)
                subdir="hpas"
                ;;
            *)
                subdir="${resource_type}"
                ;;
        esac
        
        mkdir -p "${OUTPUT_DIR}/${subdir}"
        
        # Extract each resource
        while IFS= read -r resource; do
            resource_name=$(echo "$resource" | cut -d'/' -f2)
            output_file="${OUTPUT_DIR}/${subdir}/${resource_name}.yaml"
            
            kubectl get "$resource" -n "$ns" -o yaml > "$output_file" 2>/dev/null || true
        done <<< "$resources"
    done
    
    echo "✓ Completed: $ns"
    echo ""
done

echo "=== Extraction Complete ==="
echo "Resources extracted to: $OUTPUT_BASE_DIR/"
