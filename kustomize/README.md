# Kubernetes Resources - Kustomize Templates

This directory contains extracted Kubernetes resources from the `airflow-test` and `mmjc-test` namespaces, organized for redeployment using Kustomize with parametrized image prefixes.

## Directory Structure

```
kustomize/
├── airflow-test/
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── pvcs/
│   └── kustomization.yaml
├── mmjc-test/
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── pvcs/
│   ├── ingresses/
│   └── kustomization.yaml
└── README.md
```

## Quick Start

### View Resources

To view the rendered resources without applying them:

```bash
# View airflow-test resources
kubectl kustomize kustomize/airflow-test/

# View mmjc-test resources
kubectl kustomize kustomize/mmjc-test/
```

### Apply Resources

To deploy resources to your cluster:

```bash
# Apply airflow-test resources
kubectl apply -k kustomize/airflow-test/

# Apply mmjc-test resources
kubectl apply -k kustomize/mmjc-test/
```

## Image Parametrization

### Changing Image Registry/Prefix

The kustomization.yaml files include an `images` section that allows you to easily change the registry and prefix for all images.

#### Method 1: Edit kustomization.yaml

Edit the `images` section in `kustomization.yaml`:

**Example - Change from ICR to Artifactory:**

```yaml
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: br.icr.io/br-ibm-images/mmjc-agents  # Changed registry
    newTag: 0.0.2
```

**Example - Change to air-gapped registry:**

```yaml
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: private-registry.company.com/mmjc/mmjc-agents
    newTag: 0.0.2
```

#### Method 2: Using Kustomize CLI

You can also use kustomize edit to change images:

```bash
cd kustomize/mmjc-test/

# Change a specific image
kustomize edit set image icr.io/mjc-cr/mmjc-agents=br.icr.io/br-ibm-images/mmjc-agents:0.0.2

# Change multiple images
kustomize edit set image \
  icr.io/mjc-cr/mmjc-agents=br.icr.io/br-ibm-images/mmjc-agents:0.0.2 \
  icr.io/mjc-cr/mmjc-frontend=br.icr.io/br-ibm-images/mmjc-frontend:0.0.2
```

#### Method 3: Create Overlays for Different Environments

Create environment-specific overlays:

```bash
mkdir -p kustomize/overlays/{dev,staging,prod}
```

**Example overlay (kustomize/overlays/prod/kustomization.yaml):**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../mmjc-test

namespace: mmjc-prod

images:
  # Override with production registry
  - name: icr.io/mjc-cr/mmjc-agents
    newName: prod-registry.company.com/mmjc/mmjc-agents
    newTag: 1.0.0

  - name: icr.io/mjc-cr/mmjc-frontend
    newName: prod-registry.company.com/mmjc/mmjc-frontend
    newTag: 1.0.0

# Production-specific patches
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
    target:
      kind: Deployment
      name: agents-mmjc-test
```

Apply the overlay:

```bash
kubectl apply -k kustomize/overlays/prod/
```

## Image Registries Used

### airflow-test namespace:
- `icr.io/mjc-cr/*` - IBM Cloud Registry (Custom)
- `quay.io/prometheus/*` - Prometheus metrics

### mmjc-test namespace:
- `icr.io/mjc-cr/*` - IBM Cloud Registry (Custom)
- `ghcr.io/ibm/*` - GitHub Container Registry (IBM)
- `milvusdb/*` - Milvus database
- `zilliz/*` - Attu (Milvus management)

## Common Use Cases

### 1. Migrate to Different Registry

To migrate all ICR images to a different registry:

```bash
# Edit kustomization.yaml
sed -i 's|icr.io/mjc-cr|br.icr.io/br-ibm-images|g' kustomize/mmjc-test/kustomization.yaml

# Verify changes
kubectl kustomize kustomize/mmjc-test/ | grep image:

# Apply
kubectl apply -k kustomize/mmjc-test/
```

### 2. Update Image Tags

To update all images to new tags:

```bash
cd kustomize/mmjc-test/
kustomize edit set image \
  icr.io/mjc-cr/mmjc-agents:0.0.3 \
  icr.io/mjc-cr/mmjc-frontend:0.0.3
```

### 3. Air-Gapped Deployment

For air-gapped environments, update all external images to your internal registry:

```yaml
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: internal-registry.local/mirror/mmjc-agents
    newTag: 0.0.2

  - name: milvusdb/milvus
    newName: internal-registry.local/mirror/milvus
    newTag: v2.5.15

  - name: ghcr.io/ibm/mcp-context-forge
    newName: internal-registry.local/mirror/mcp-context-forge
    newTag: 0.6.0
```

### 4. Dry Run Before Applying

Always preview changes before applying:

```bash
# Dry run
kubectl apply -k kustomize/mmjc-test/ --dry-run=client -o yaml

# Diff with current cluster state
kubectl diff -k kustomize/mmjc-test/
```

## Resource Management

### Secrets

Note: Secret values are exported from the cluster. For security:
1. Never commit secrets to version control
2. Use external secret management (e.g., Vault, Sealed Secrets)
3. Consider using kustomize secretGenerator with separate files

### PersistentVolumeClaims

PVCs are included but will create new volumes when applied. To preserve data:
1. Backup existing PVCs before redeployment
2. Consider using existing PVCs by removing them from kustomization.yaml
3. Use storage migration tools if changing storage classes

## Validation

Validate your kustomize configuration:

```bash
# Validate YAML syntax
kubectl kustomize kustomize/mmjc-test/ | kubectl apply --dry-run=client -f -

# Check for deprecated API versions
kubectl kustomize kustomize/mmjc-test/ | kubectl apply --dry-run=server -f -
```

## Cleanup

To remove all resources:

```bash
kubectl delete -k kustomize/airflow-test/
kubectl delete -k kustomize/mmjc-test/
```

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Image Configuration](https://kubernetes.io/docs/concepts/containers/images/)
- [Kustomize Image Transformer](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/image.md)

## Notes

- The exported YAMLs have been cleaned of runtime metadata (UIDs, resourceVersions, etc.)
- Common labels have been added for tracking (environment: test, managed-by: kustomize)
- Helm release metadata is preserved in annotations
- Service accounts and RBAC resources may need to be created separately
- Consider reviewing and updating resource requests/limits before production deployment
