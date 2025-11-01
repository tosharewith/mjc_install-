# Common Configuration for All Services

This directory contains **centralized configuration** that is shared across all namespaces and services.

## 📁 Structure

```
common-config/
├── kustomization.yaml          # Generates ConfigMaps & Secrets
├── s3-config.env              # S3/Object Storage settings
├── llm-config.env             # LLM/AI model endpoints
├── database-config.env        # Database connections
├── application-config.env     # General app settings
└── README.md                  # This file
```

## 🎯 How It Works

### 1. **ONE Place for Configuration**

Instead of repeating the same S3 endpoint, LLM settings, etc. in every deployment, define them **once here**.

### 2. **Generated ConfigMaps**

Kustomize automatically creates ConfigMaps from the `.env` files:

```yaml
# From s3-config.env →
apiVersion: v1
kind: ConfigMap
metadata:
  name: s3-config-<hash>
data:
  S3_ENDPOINT: https://s3.us-south.cloud-object-storage.appdomain.cloud
  S3_REGION: us-south
  S3_BUCKET_AIRFLOW_DAGS: mmjc-airflow-dags
  ...
```

### 3. **Generated Secrets**

Secrets are also generated (use placeholders here, actual values from vault/sealed-secrets):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: s3-credentials-<hash>
data:
  access-key: <base64-encoded>
  secret-key: <base64-encoded>
```

## 📝 Usage in Deployments

### Option 1: Inject All Environment Variables

```yaml
# In your deployment
spec:
  template:
    spec:
      containers:
      - name: my-app
        envFrom:
          # Inject all S3 config
          - configMapRef:
              name: s3-config
          # Inject all LLM config
          - configMapRef:
              name: llm-config
          # Inject S3 credentials
          - secretRef:
              name: s3-credentials
```

### Option 2: Selective Environment Variables

```yaml
# Pick specific values
env:
  - name: S3_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: s3-config
        key: S3_ENDPOINT
  
  - name: S3_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: s3-credentials
        key: access-key
```

### Option 3: Mount as Files

```yaml
# Mount config as files
volumeMounts:
  - name: s3-config
    mountPath: /etc/config/s3
    readOnly: true

volumes:
  - name: s3-config
    configMap:
      name: s3-config
```

## 🔧 Configuration Files

### s3-config.env
S3/Object Storage configuration used by:
- `mcp-git-s3-server`
- `mcp-arc-s3-server`
- `airflow` (for DAG storage)

### llm-config.env
LLM/AI model configuration used by:
- `agents-mmjc`
- `mcp-gateway`
- `mcp-milvus-db`
- `mermaid-validator-api`

### database-config.env
Database connection settings used by:
- `po-mmjc`
- `agents-mmjc`
- `airflow`

### application-config.env
General application settings used by:
- All services

## 🔐 Managing Secrets

### Development/Test

For dev/test, you can use literal values:

```yaml
secretGenerator:
  - name: s3-credentials
    literals:
      - access-key=dev-access-key
      - secret-key=dev-secret-key
```

### Production

For production, use **External Secrets Operator** or **Sealed Secrets**:

#### External Secrets Operator

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: s3-credentials
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: s3-credentials
  data:
    - secretKey: access-key
      remoteRef:
        key: s3/access-key
    - secretKey: secret-key
      remoteRef:
        key: s3/secret-key
```

#### Sealed Secrets

```bash
# Encrypt secret
kubeseal -f s3-credentials.yaml -w s3-credentials-sealed.yaml

# Apply sealed secret
kubectl apply -f s3-credentials-sealed.yaml
```

## 📊 Environment-Specific Overrides

Use overlays to override values per environment:

```
kustomize/
├── base/common-config/         # Base config
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml  # Override for dev
│   ├── staging/
│   │   └── kustomization.yaml  # Override for staging
│   └── prod/
│       └── kustomization.yaml  # Override for prod
```

**Example overlay (overlays/prod/kustomization.yaml):**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base/common-config

namespace: mmjc-prod

# Override specific ConfigMap values for production
configMapGenerator:
  - name: application-config
    behavior: merge
    literals:
      - ENVIRONMENT=production
      - LOG_LEVEL=WARN
      - DEBUG=false
```

## 🚀 Deployment

### Preview generated resources

```bash
kubectl kustomize kustomize/base/common-config/
```

### Apply to cluster

```bash
# From namespace kustomization (includes common-config)
kubectl apply -k kustomize/mmjc-test/

# Or directly (not recommended)
kubectl apply -k kustomize/base/common-config/
```

## 🔄 Updating Configuration

1. **Edit the .env files:**
   ```bash
   vim kustomize/base/common-config/s3-config.env
   ```

2. **Apply changes:**
   ```bash
   kubectl apply -k kustomize/mmjc-test/
   ```

3. **Restart pods to pick up new config:**
   ```bash
   kubectl rollout restart deployment -n mmjc-test
   ```

## ✅ Benefits

1. **Single Source of Truth** - Update S3 endpoint once, affects all services
2. **DRY Principle** - Don't repeat configuration across deployments
3. **Environment Management** - Easy to create dev/staging/prod variants
4. **Version Control** - Configuration changes tracked in git
5. **Consistent Naming** - All services use same ConfigMap/Secret names

## ⚠️ Important Notes

- ConfigMap/Secret names get a **hash suffix** (e.g., `s3-config-abc123`)
- This ensures rolling updates when config changes
- Services automatically get new config without manual updates
- **Don't commit real secrets** - use placeholders + external secret management

---

**See Also:**
- [Kustomize ConfigMap Generator](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
