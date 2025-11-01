# Kubernetes Resources - Complete Extraction

This directory contains the complete extraction of all Kubernetes resources from production namespaces.

## 📋 Overview

**Extraction Date:** $(date)
**Source Cluster:** mjc-cluster/d091ramd0q70n6ktn9v0
**Namespaces:** airflow-test, mmjc-test, mmjc-dev

## 📁 Directory Structure

```
originals/
├── airflow-test/           # Airflow production resources
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/            ⚠️ CONTAINS ACTUAL CREDENTIALS
│   ├── pvcs/
│   ├── serviceaccounts/
│   ├── roles/
│   └── rolebindings/
│
├── mmjc-test/              # MMJC test environment
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/            ⚠️ CONTAINS ACTUAL CREDENTIALS
│   ├── pvcs/
│   ├── ingresses/
│   ├── networkpolicies/
│   ├── serviceaccounts/
│   ├── roles/
│   ├── rolebindings/
│   └── hpas/
│
├── mmjc-dev/               # MMJC development environment
│   ├── deployments/
│   ├── statefulsets/
│   ├── services/
│   ├── configmaps/
│   ├── secrets/            ⚠️ CONTAINS ACTUAL CREDENTIALS
│   ├── pvcs/
│   ├── ingresses/
│   ├── networkpolicies/
│   ├── serviceaccounts/
│   ├── roles/
│   ├── rolebindings/
│   ├── hpas/
│   └── jobs/
│
├── secret-templates/       # Templated secrets (safe for VCS)
│   ├── airflow-test/
│   ├── mmjc-test/
│   └── mmjc-dev/
│
├── INVENTORY.md           # Detailed resource inventory
├── README.md              # This file
├── template-secrets.sh    # Advanced secret templating (Python)
└── template-secrets-simple.sh  # Simple secret templating (Shell)
```

## ⚠️ Security Warning

### Secrets Directory

The `secrets/` directories contain **ACTUAL PRODUCTION CREDENTIALS** including:
- Database passwords and connection strings
- API keys and tokens
- TLS certificates and private keys
- Docker registry credentials
- JWT secrets and encryption keys
- OAuth tokens and client secrets

**CRITICAL SECURITY REQUIREMENTS:**

1. ✅ **DO NOT commit originals/*/secrets/ to version control**
2. ✅ **Add to .gitignore immediately:**
   ```bash
   echo "originals/*/secrets/" >> .gitignore
   ```
3. ✅ **Restrict file system permissions:**
   ```bash
   chmod 700 originals/*/secrets/
   chmod 600 originals/*/secrets/*.yaml
   ```
4. ✅ **Use secret-templates/ for version control instead**
5. ✅ **Use proper secret management for production:**
   - HashiCorp Vault
   - Sealed Secrets
   - External Secrets Operator
   - Cloud provider secret managers (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault)

## 📊 Resource Summary

### airflow-test (Production Airflow)
- Deployments: 4
- StatefulSets: 2
- Services: 4
- ConfigMaps: 4
- Secrets: 19
- PVCs: 3
- ServiceAccounts: 9
- Roles: 2
- RoleBindings: 2

### mmjc-test (Test Environment)
- Deployments: 13
- StatefulSets: 6
- Services: 25
- ConfigMaps: 17
- Secrets: 24
- PVCs: 17
- Ingresses: 2
- NetworkPolicies: 1
- ServiceAccounts: 5
- Roles: 1
- RoleBindings: 1
- HorizontalPodAutoscalers: 3

### mmjc-dev (Development Environment)
- Deployments: 23
- StatefulSets: 6
- Services: 42
- ConfigMaps: 29
- Secrets: 37
- PVCs: 24
- Ingresses: 3
- NetworkPolicies: 1
- ServiceAccounts: 7
- Roles: 2
- RoleBindings: 2
- HorizontalPodAutoscalers: 5
- Jobs: 1

**Total Resources Extracted: 300+**

## 🚀 Usage

### View a Specific Resource

```bash
# View a deployment
cat originals/mmjc-test/deployments/agents-mmjc-test.yaml

# View a service
cat originals/airflow-test/services/airflow-test-api-server.yaml

# View a configmap
cat originals/mmjc-dev/configmaps/mcp-git-s3-config.yaml
```

### List All Resources of a Type

```bash
# List all deployments
ls originals/*/deployments/

# List all secrets (be careful!)
ls originals/*/secrets/

# List all statefulsets
ls originals/*/statefulsets/
```

### Search for Specific Configuration

```bash
# Find all resources using a specific image
grep -r "icr.io/mjc-cr/mmjc-agents" originals/*/deployments/

# Find all services of type LoadBalancer
grep -r "type: LoadBalancer" originals/*/services/

# Find all ingress rules
cat originals/*/ingresses/*.yaml
```

### Count Resources

```bash
# Total YAML files
find originals -name "*.yaml" -type f | wc -l

# Count by type
for dir in originals/mmjc-test/*/; do
    echo "$(basename $dir): $(ls $dir 2>/dev/null | wc -l)"
done
```

## 🔒 Working with Secrets

### Create Safe Templates

Use the provided scripts to create safe, templated versions:

```bash
# Simple shell-based templating
bash originals/template-secrets-simple.sh

# Advanced Python-based templating (requires Python 3 + PyYAML)
bash originals/template-secrets.sh
```

This creates `secret-templates/` directory with placeholders instead of actual values.

### Example Template Usage

After templating, secrets look like this:

```yaml
# WARNING: This is a TEMPLATE - Replace all PLACEHOLDER values before use
apiVersion: v1
kind: Secret
metadata:
  name: database-password
  namespace: mmjc-test
type: Opaque
data:
  password: REPLACE_WITH_BASE64_ENCODED_VALUE_FOR_password
  username: REPLACE_WITH_BASE64_ENCODED_VALUE_FOR_username
```

### Applying Templated Secrets

1. Copy template to your work directory
2. Replace placeholders with actual base64-encoded values
3. Apply:
```bash
kubectl apply -f secret-templates/mmjc-test/database-password.yaml
```

Or better yet, use a secret management solution:

```bash
# Using sealed-secrets
kubeseal -f secret-templates/mmjc-test/database-password.yaml \
  -w sealed-database-password.yaml

# Using external-secrets with Vault
kubectl apply -f external-secret-config.yaml
```

## 🔄 Redeployment Workflows

### Option 1: Direct Application

```bash
# Apply all resources from a namespace
kubectl apply -f originals/mmjc-test/deployments/
kubectl apply -f originals/mmjc-test/services/
kubectl apply -f originals/mmjc-test/configmaps/
# Note: Handle secrets separately with proper security
```

### Option 2: Use with Kustomize

The `kustomize/` directory (sibling to originals/) provides a better workflow:

```bash
# Use kustomize for templated deployment
kubectl apply -k ../kustomize/mmjc-test/

# With overlays for different environments
kubectl apply -k ../kustomize/overlays/production/
```

### Option 3: Convert to Helm Charts

Use the extracted YAMLs as base for creating Helm charts:

```bash
# Create Helm chart structure
helm create mmjc-app
# Copy resources to templates/
# Parameterize values
# Package and deploy
```

## 📝 Important Notes

### Resource Cleanup

The extracted YAMLs contain runtime metadata that should be removed before redeployment:

- `resourceVersion`
- `uid`
- `creationTimestamp`
- `generation`
- `status`

The kustomize configurations handle this automatically.

### PersistentVolumeClaims

PVCs reference specific PVs and storage classes. Before redeploying:

1. Verify storage classes exist in target cluster
2. Consider data migration strategy
3. Update storage class names if different
4. Plan for data backup/restore

### Image References

All images are extracted with their full registry paths:
- `icr.io/mjc-cr/*` - IBM Cloud Registry
- `ghcr.io/ibm/*` - GitHub Container Registry
- `milvusdb/*` - Docker Hub
- `quay.io/*` - Quay.io

For air-gapped deployments, update image references to your internal registry.

### StatefulSets

StatefulSets have special considerations:
- Ordered pod creation/deletion
- Persistent volume claim templates
- Service dependencies
- Headless services

Review carefully before modifying.

## 🛠️ Maintenance

### Re-extract Resources

To refresh the extraction:

```bash
# Re-run the extraction script
bash ../extract-all-resources.sh

# Or extract a specific namespace
kubectl get all,cm,secret,pvc,ing,netpol,sa,role,rolebinding,hpa,job,cronjob \
  -n mmjc-test -o yaml > mmjc-test-backup-$(date +%Y%m%d).yaml
```

### Backup Strategy

1. Keep originals/ directory as snapshot reference
2. Use git tags for versioning: `git tag -a v1.0-snapshot -m "Cluster snapshot 2025-10-31"`
3. Store securely (encrypted backup for secrets/)
4. Regular refresh cadence (weekly/monthly)

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)

## 🆘 Troubleshooting

### Issue: Permission Denied on Secrets

```bash
chmod 600 originals/*/secrets/*.yaml
```

### Issue: Resource Already Exists

Remove `resourceVersion` and `uid` before reapplying:

```bash
grep -v "resourceVersion:" original.yaml | \
grep -v "uid:" | \
kubectl apply -f -
```

### Issue: Image Pull Errors

Ensure imagePullSecrets are created:

```bash
kubectl get secret all-icr-io-mmjc -n mmjc-test -o yaml | \
  kubectl apply -n target-namespace -f -
```

---

**Last Updated:** $(date)
**Maintainer:** DevOps Team
**Status:** Active Snapshot

---

## ⚠️ IMPORTANT: Secret Templating Update

### Use This Script ONLY:

```bash
bash template-secrets-perl.sh
```

This is the **ONLY** script that properly removes ALL sensitive data including:
- Base64 encoded credentials
- Plaintext secrets in multi-line annotations
- Runtime metadata

### ❌ DO NOT USE These Scripts:
- `template-secrets-simple.sh` - Incomplete
- `template-secrets.sh` - Requires Python/PyYAML  
- `template-secrets-final.sh` - Leaves plaintext in annotations
- `template-secrets-secure.sh` - Sed limitations
- `template-secrets-shell.sh` - AWK errors

See **`../SECURITY_FIX_SECRETS.md`** for details on the security issue and fix.

---
