# Centralized Configuration with Kustomize

## ✅ YES! You Can Have ONE Place for All Common Config

All your S3 credentials, LLM endpoints, database connections, etc. can be defined **once** and used by all services.

---

## 📁 Location

```
kustomize/base/common-config/
├── kustomization.yaml          # Generates ConfigMaps & Secrets
├── s3-config.env              # S3/Object Storage
├── llm-config.env             # LLM/AI endpoints
├── database-config.env        # Database connections
├── application-config.env     # App settings
├── README.md                  # Detailed guide
└── EXAMPLE_USAGE.yaml         # Usage examples
```

---

## 🎯 How It Works

### 1. Define Config Once

**kustomize/base/common-config/s3-config.env:**
```env
S3_ENDPOINT=https://s3.us-south.cloud-object-storage.appdomain.cloud
S3_REGION=us-south
S3_BUCKET_AIRFLOW_DAGS=mmjc-airflow-dags
S3_USE_SSL=true
```

### 2. Kustomize Generates ConfigMaps

```bash
$ kubectl kustomize kustomize/base/common-config/

apiVersion: v1
kind: ConfigMap
metadata:
  name: s3-config-abc123  # ← Hash ensures rolling updates
data:
  S3_ENDPOINT: https://s3.us-south...
  S3_REGION: us-south
  ...
```

### 3. Reference in Any Deployment

**Option A: Inject all environment variables**
```yaml
spec:
  containers:
  - name: my-app
    envFrom:
      - configMapRef:
          name: s3-config      # All S3 vars injected
      - secretRef:
          name: s3-credentials # All S3 secrets injected
```

**Option B: Pick specific variables**
```yaml
env:
  - name: S3_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: s3-config
        key: S3_ENDPOINT
```

**Option C: Mount as files**
```yaml
volumeMounts:
  - name: s3-config
    mountPath: /etc/config/s3
volumes:
  - name: s3-config
    configMap:
      name: s3-config
```

---

## 📦 What's Included

### ConfigMaps (4)

| Name | Purpose | Used By |
|------|---------|---------|
| `s3-config` | S3/Object Storage | mcp-git-s3, mcp-arc-s3, airflow |
| `llm-config` | LLM/AI endpoints | agents, mcp-gateway, mermaid-validator |
| `database-config` | DB connections | po, agents, airflow |
| `application-config` | General settings | All services |

### Secrets (3) - Template Only

| Name | Purpose |
|------|---------|
| `s3-credentials` | S3 access/secret keys |
| `llm-api-keys` | Azure OpenAI, OpenAI keys |
| `database-credentials` | DB passwords |

**⚠️ Note:** Secret values are placeholders. Use External Secrets Operator or Sealed Secrets for production.

---

## 🚀 Quick Start

### 1. Reference common-config in your namespace

**kustomize/mmjc-test/kustomization.yaml:**
```yaml
resources:
  - ../base/common-config  # ← Add this
  - deployments/agents.yaml
  - deployments/frontend.yaml
  ...
```

### 2. Update deployment to use config

**Before:**
```yaml
env:
  - name: S3_ENDPOINT
    value: https://s3.us-south.cloud-object-storage.appdomain.cloud
  - name: S3_REGION
    value: us-south
  - name: AZURE_OPENAI_ENDPOINT
    value: https://your-resource.openai.azure.com
```

**After:**
```yaml
envFrom:
  - configMapRef:
      name: s3-config
  - configMapRef:
      name: llm-config
```

### 3. Deploy

```bash
kubectl apply -k kustomize/mmjc-test/
```

---

## 🔄 Update Configuration

### Change S3 endpoint for all services:

```bash
# 1. Edit config file
vim kustomize/base/common-config/s3-config.env
# Change: S3_ENDPOINT=https://new-endpoint.com

# 2. Apply
kubectl apply -k kustomize/mmjc-test/

# 3. Pods automatically restart with new config (hash changed)
```

---

## 🌍 Environment-Specific Overrides

### Development
```
kustomize/overlays/dev/
└── kustomization.yaml    # S3_BUCKET=dev-bucket
```

### Staging
```
kustomize/overlays/staging/
└── kustomization.yaml    # S3_BUCKET=staging-bucket
```

### Production
```
kustomize/overlays/prod/
└── kustomization.yaml    # S3_BUCKET=prod-bucket
```

**Deploy to specific environment:**
```bash
kubectl apply -k kustomize/overlays/prod/
```

---

## 🔐 Secret Management

### For Development/Test

Use placeholders in kustomization.yaml:
```yaml
secretGenerator:
  - name: s3-credentials
    literals:
      - access-key=<REPLACE>
      - secret-key=<REPLACE>
```

### For Production

**Option 1: External Secrets Operator** (Recommended)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: s3-credentials
spec:
  secretStoreRef:
    name: vault-backend
  data:
    - secretKey: access-key
      remoteRef:
        key: s3/access-key
```

**Option 2: Sealed Secrets**
```bash
kubeseal -f secret.yaml -w sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

**Option 3: Vault CSI Driver**
```yaml
volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      volumeAttributes:
        secretProviderClass: vault-s3-creds
```

---

## ✅ Benefits

| Before | After |
|--------|-------|
| S3 endpoint in 10 files | S3 endpoint in 1 file |
| Change DB host = 10 updates | Change DB host = 1 update |
| Hard to find config | All config in one place |
| Secrets copy-pasted | Secrets generated once |
| Environment drift | Consistent config |

---

## 📚 Resources

- **Detailed Guide:** `kustomize/base/common-config/README.md`
- **Examples:** `kustomize/base/common-config/EXAMPLE_USAGE.yaml`
- **Kustomize Docs:** https://kustomize.io/
- **ConfigMap Generator:** https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/

---

## 🎬 Next Steps

1. ✅ Common config structure created
2. ✅ Example .env files provided
3. ✅ mmjc-test references common-config
4. ⏭️ **You do:** Update deployments to use `envFrom`
5. ⏭️ **You do:** Replace placeholder secrets with real values
6. ⏭️ **You do:** Test deployment: `kubectl apply -k kustomize/mmjc-test/`

---

**Status:** ✅ Ready to use
**Location:** `kustomize/base/common-config/`
**Documentation:** Complete
