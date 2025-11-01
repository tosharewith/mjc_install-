# Kubernetes Resources - Complete Index

## 📚 Quick Navigation

### 🎯 Start Here
1. **[EXTRACTION_SUMMARY.md](EXTRACTION_SUMMARY.md)** - Complete overview of what was extracted
2. **[K8S_RESOURCES_INVENTORY.md](K8S_RESOURCES_INVENTORY.md)** - High-level resource inventory

### 📁 Main Directories

#### `originals/` - Complete Raw Extraction
- **[originals/README.md](originals/README.md)** - How to use original YAMLs
- **[originals/INVENTORY.md](originals/INVENTORY.md)** - Detailed resource listing
- `originals/airflow-test/` - Airflow production (49 resources)
- `originals/mmjc-test/` - MMJC test environment (115 resources)
- `originals/mmjc-dev/` - MMJC development (182 resources)
- `originals/secret-templates/` - Safe secret templates (80 files)

⚠️ **Warning:** `originals/*/secrets/` contains actual credentials!

#### `kustomize/` - Templates for Redeployment
- **[kustomize/README.md](kustomize/README.md)** - Comprehensive Kustomize usage guide
- `kustomize/airflow-test/` - Airflow Kustomize templates
- `kustomize/mmjc-test/` - MMJC test Kustomize templates
- `kustomize/overlays/artifactory/` - Artifactory registry overlay
- `kustomize/overlays/air-gapped/` - Air-gapped deployment overlay

### 🛠️ Utility Scripts

| Script | Purpose |
|--------|---------|
| `extract-all-resources.sh` | Re-extract all resources from cluster |
| `verify-extraction.sh` | Verify extraction completeness |
| `kustomize/validate.sh` | Validate Kustomize configurations |
| `kustomize/change-image-registry.sh` | Helper to change image registries |
| `originals/template-secrets.sh` | Advanced secret templating (Python) |
| `originals/template-secrets-simple.sh` | Simple secret templating (Shell) |

---

## 🚀 Common Tasks

### View Resources

```bash
# List all deployments
ls originals/*/deployments/

# View a specific deployment
cat originals/mmjc-test/deployments/agents-mmjc-test.yaml

# Find all images used
grep -r "image:" kustomize/*/deployments/ | grep -v "imagePullPolicy"
```

### Change Image Registry

```bash
# Option 1: Use helper script
./kustomize/change-image-registry.sh mmjc-test \
  icr.io/mjc-cr \
  br.icr.io/br-ibm-images

# Option 2: Edit kustomization.yaml
vim kustomize/mmjc-test/kustomization.yaml

# Option 3: Use overlay
kubectl apply -k kustomize/overlays/artifactory/
```

### Deploy Resources

```bash
# Preview with kustomize
kubectl kustomize kustomize/mmjc-test/

# Dry-run deployment
kubectl apply -k kustomize/mmjc-test/ --dry-run=client

# Deploy
kubectl apply -k kustomize/mmjc-test/
```

### Work with Secrets

```bash
# Create safe templates
bash originals/template-secrets-simple.sh

# View templates
ls originals/secret-templates/mmjc-test/

# Use template (after replacing placeholders)
kubectl apply -f originals/secret-templates/mmjc-test/api-key.yaml
```

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Namespaces** | 3 |
| **Total Resources** | 346 |
| **Deployments** | 40 |
| **StatefulSets** | 14 |
| **Services** | 71 |
| **Secrets** | 80 |
| **ConfigMaps** | 50 |
| **PVCs** | 44 |
| **Ingresses** | 5 |
| **Total YAML Files** | 527 |
| **Secret Templates** | 80 |
| **Unique Images** | 11 |

---

## 🔍 Find Resources

### By Type

```bash
# All deployments
find originals -path "*/deployments/*.yaml"

# All services
find originals -path "*/services/*.yaml"

# All secrets (be careful!)
find originals -path "*/secrets/*.yaml" -not -path "*/secret-templates/*"
```

### By Name Pattern

```bash
# Find all airflow resources
find originals -name "*airflow*"

# Find all milvus resources
find originals -name "*milvus*"

# Find all agent resources
find originals -name "*agent*"
```

### By Content

```bash
# Find resources using specific image
grep -r "icr.io/mjc-cr/mmjc-agents" originals/

# Find LoadBalancer services
grep -r "type: LoadBalancer" originals/*/services/

# Find resources with specific labels
grep -r "app: mcp-gateway" originals/
```

---

## 🔒 Security Checklist

- [ ] Secrets directory added to .gitignore ✅
- [ ] File permissions set on secrets: `chmod 600 originals/*/secrets/*.yaml`
- [ ] Secret templates created: `bash originals/template-secrets-simple.sh` ✅
- [ ] Documented secret management strategy
- [ ] Credentials rotated after extraction (recommended)
- [ ] Backup encrypted and stored securely
- [ ] Access to originals/ restricted

---

## 📖 Documentation Index

### Overview Documents
- [INDEX.md](INDEX.md) ← You are here
- [EXTRACTION_SUMMARY.md](EXTRACTION_SUMMARY.md) - Complete summary
- [K8S_RESOURCES_INVENTORY.md](K8S_RESOURCES_INVENTORY.md) - Resource inventory

### Detailed Guides
- [originals/README.md](originals/README.md) - Working with original YAMLs
- [originals/INVENTORY.md](originals/INVENTORY.md) - Resource listing
- [kustomize/README.md](kustomize/README.md) - Kustomize usage guide

### Script Documentation
- Scripts are self-documenting with `--help` or usage info
- Read script headers for detailed usage

---

## 🆘 Troubleshooting

### Issue: Too many files to commit

**Solution:** Only commit templates, not originals:
```bash
git add kustomize/ originals/secret-templates/ *.md
git add .gitignore
# DO NOT: git add originals/*/secrets/
```

### Issue: Images not accessible

**Solution:** Update image references:
```bash
./kustomize/change-image-registry.sh <namespace> <old-prefix> <new-prefix>
```

### Issue: Resources already exist

**Solution:** Use server-side apply:
```bash
kubectl apply -k kustomize/mmjc-test/ --server-side
```

---

## 📅 Maintenance

### Regular Tasks (Monthly)

1. **Re-extract resources:**
   ```bash
   bash extract-all-resources.sh
   ```

2. **Update templates:**
   ```bash
   bash originals/template-secrets-simple.sh
   ```

3. **Verify extraction:**
   ```bash
   bash verify-extraction.sh
   ```

4. **Commit changes:**
   ```bash
   git add kustomize/ originals/secret-templates/ *.md
   git commit -m "Update k8s templates - $(date +%Y-%m-%d)"
   git tag "snapshot-$(date +%Y-%m-%d)"
   ```

### Backup Strategy

1. Keep `originals/` as point-in-time snapshot
2. Tag git commits: `git tag v1.0-snapshot-YYYY-MM-DD`
3. Store encrypted backups of `secrets/` separately
4. Document manual cluster changes

---

## 🔗 External Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)

---

**Last Updated:** $(date +"%Y-%m-%d %H:%M:%S")
**Status:** ✅ Complete and Verified
**Total Files:** 527 YAML files
**Maintainer:** DevOps Team
