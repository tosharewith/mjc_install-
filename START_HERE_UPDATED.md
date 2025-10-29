# 🚀 START HERE - Image Migration (UPDATED)

**Target**: `br.icr.io/br-ibm-images/` (Brazil Region)
**Images**: ONLY our custom images (NOT public images due to licensing)
**JFrog**: Optional support for Artifactory proxy
**Time**: 5-10 minutes (only 1 image now, ~2GB)

---

## 🎯 IMPORTANT CHANGES

### What We're Migrating:

**✅ WILL MIGRATE** (our custom images):
- `us.icr.io/mmjc-cr/mmjc-airflow-service:latest` → `br.icr.io/br-ibm-images/mmjc-airflow-service:latest`

**❌ NOT MIGRATING** (public images - licensing restrictions):
- ~~`milvusdb/milvus:v2.5.15`~~ (stays in docker.io)
- ~~`docker.io/milvusdb/etcd:3.5.18-r1`~~ (stays in docker.io)
- ~~`docker.io/bitnami/kafka:3.1.0...`~~ (stays in docker.io)
- ~~`docker.io/bitnami/zookeeper:3.7.0...`~~ (stays in docker.io)
- ~~`quay.io/prometheus/statsd-exporter`~~ (stays in quay.io)

**Reason**: We cannot redistribute public images due to licensing. They will be pulled from original registries.

### Target Registry:

**Primary**: `br.icr.io/br-ibm-images/`
**Region**: Brazil (São Paulo)
**Namespace**: `br-ibm-images`

**Optional JFrog**: If you use JFrog Artifactory as a proxy, images will also be accessible via:
- `artifactory.company.com/ibm-cr-remote/br-ibm-images/mmjc-airflow-service:latest`

---

## ✅ Prerequisites

### 1. Namespace Must Exist

```bash
# Check if namespace exists
ibmcloud cr region-set br.icr.io
ibmcloud cr namespace-list | grep br-ibm-images
```

**If NOT found**: See `SETUP_NAMESPACE.md` for instructions to create it (requires Manager access)

### 2. You Have Access

```bash
# Test access (should work without error)
ibmcloud cr images --restrict br-ibm-images
```

**Expected**: Should show list (even if empty) without "unauthorized" error

---

## ⚡ QUICK START (5 Commands)

```bash
# 1. Navigate to project
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration

# 2. Setup Docker with Colima
source ./scripts/setup-docker-colima.sh

# 3. Login to IBM Cloud Brazil registry
ibmcloud cr region-set br.icr.io
ibmcloud cr login

# 4. Run migration (now only 1 image, ~2GB)
./scripts/migrate-images-manual.sh

# 5. Update Kubernetes manifests
./scripts/update-image-refs.sh
```

**Time**: 5-10 minutes (down from 30-60 min - only migrating 1 custom image)

---

## 📋 What Gets Migrated

### BEFORE Migration:

```
SOURCE (us-south region):
  us.icr.io/mmjc-cr/mmjc-airflow-service:latest  (~2GB)

PUBLIC REGISTRIES (not touched):
  docker.io/milvusdb/milvus:v2.5.15
  docker.io/milvusdb/etcd:3.5.18-r1
  docker.io/bitnami/kafka:3.1.0-debian-10-r52
  docker.io/bitnami/zookeeper:3.7.0-debian-10-r320
  quay.io/prometheus/statsd-exporter:v0.28.0
```

### AFTER Migration:

```
TARGET (br-sao region):
  br.icr.io/br-ibm-images/mmjc-airflow-service:latest  ✅ MIGRATED

PUBLIC REGISTRIES (unchanged):
  docker.io/milvusdb/milvus:v2.5.15                    (not migrated)
  docker.io/milvusdb/etcd:3.5.18-r1                    (not migrated)
  docker.io/bitnami/kafka:3.1.0-debian-10-r52          (not migrated)
  docker.io/bitnami/zookeeper:3.7.0-debian-10-r320     (not migrated)
  quay.io/prometheus/statsd-exporter:v0.28.0           (not migrated)
```

### Kubernetes Manifests Updated:

```yaml
# kustomize/airflow-test/kustomization.yaml
images:
  - name: us.icr.io/mmjc-cr/mmjc-airflow-service
    newName: br.icr.io/br-ibm-images/mmjc-airflow-service
    newTag: latest

# Public images stay in original registries:
# - milvusdb/milvus → docker.io/milvusdb/milvus (no change)
# - bitnami/kafka → docker.io/bitnami/kafka (no change)
# etc.
```

---

## 🔧 Optional: JFrog Artifactory Support

If you use JFrog Artifactory as a proxy for IBM CR:

### Configure:

```bash
# Edit config
vim config/migration.env

# Add:
JFROG_PREFIX=artifactory.yourcompany.com/ibm-cr-remote/
JFROG_ENABLED=true
```

### Result:

Images will be documented as accessible via both paths:
- **Direct**: `br.icr.io/br-ibm-images/mmjc-airflow-service:latest`
- **JFrog**: `artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-airflow-service:latest`

**Note**: JFrog must be configured to mirror/proxy IBM Container Registry

---

## 📊 Migration Flow

```
┌─────────────────────────────────────────────────────────────┐
│ SOURCE: us.icr.io/mmjc-cr/                                  │
│   mmjc-airflow-service:latest (OUR custom Airflow image)   │
└─────────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────┐
        │  PULL to your Mac (~2GB)        │
        │  Via Colima Docker              │
        └─────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────┐
        │  TAG for target registry        │
        │  br.icr.io/br-ibm-images/...    │
        └─────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────┐
        │  PUSH to target (~2GB upload)   │
        │  Brazil region (São Paulo)      │
        └─────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ TARGET: br.icr.io/br-ibm-images/                            │
│   mmjc-airflow-service:latest ✅                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────┐
        │  UPDATE Kubernetes manifests    │
        │  Point to new registry          │
        └─────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PUBLIC IMAGES: Stay in original registries                 │
│   docker.io/milvusdb/milvus:v2.5.15                        │
│   docker.io/bitnami/kafka:3.1.0...                         │
│   (not touched due to licensing)                            │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Verification

### After Migration:

```bash
# 1. Check image in target registry
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images | grep mmjc-airflow-service

# Expected output:
# br.icr.io/br-ibm-images/mmjc-airflow-service   latest   ...   ~2GB

# 2. Check updated manifests
grep "br.icr.io/br-ibm-images" kustomize/airflow-test/kustomization.yaml

# Expected:
#   newName: br.icr.io/br-ibm-images/mmjc-airflow-service

# 3. Verify public images NOT in target
ibmcloud cr images --restrict br-ibm-images | grep -E "(milvus|kafka|zookeeper)"

# Expected: Empty (public images not migrated)

# 4. Test Kubernetes build
kubectl kustomize kustomize/airflow-test/ | grep -A 2 "image:"

# Expected: Mix of:
#   - br.icr.io/br-ibm-images/mmjc-airflow-service (our custom image)
#   - docker.io/milvusdb/milvus (public image)
#   - docker.io/bitnami/kafka (public image)
```

---

## 🚫 What Changed from Original Plan

| Aspect | Original | Updated |
|--------|----------|---------|
| **Images to migrate** | 5 images (~5GB) | 1 image (~2GB) |
| **Public images** | Migrate all | ❌ Don't migrate (licensing) |
| **Target registry** | `us.icr.io/mmjc-cr` | `br.icr.io/br-ibm-images` |
| **Region** | US South | Brazil São Paulo |
| **Migration time** | 30-60 min | 5-10 min |
| **JFrog support** | No | ✅ Yes (optional) |

---

## 🆘 Troubleshooting

### Error: "Namespace br-ibm-images not found"

**Solution**: Create namespace or use existing one. See `SETUP_NAMESPACE.md`

### Error: "Unauthorized to access namespace"

**Solution**: Request Manager/Writer access from IBM Cloud admin

### Public Images Not Pulling

**Solution**: This is correct! Public images should pull from original registries:
- `docker.io/milvusdb/milvus:v2.5.15`
- `docker.io/bitnami/kafka:...`

No action needed - this is expected behavior.

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| `START_HERE_UPDATED.md` | This file - updated quick start |
| `SETUP_NAMESPACE.md` | Create br-ibm-images namespace |
| `MIGRATION_WORKFLOW.md` | Detailed workflow explanation |
| `SERVICES_AND_IMAGES_GUIDE.md` | Architecture details |

---

## 🎉 Success Criteria

After successful migration:

- ✅ 1 image in `br.icr.io/br-ibm-images/`:
  ```bash
  ibmcloud cr images --restrict br-ibm-images
  # Shows: mmjc-airflow-service:latest
  ```

- ✅ Kustomization updated:
  ```bash
  grep "br.icr.io/br-ibm-images" kustomize/airflow-test/kustomization.yaml
  # Shows: newName: br.icr.io/br-ibm-images/mmjc-airflow-service
  ```

- ✅ Public images NOT in target:
  ```bash
  ibmcloud cr images --restrict br-ibm-images | wc -l
  # Shows: 1 (only our custom image)
  ```

- ✅ Kubernetes manifests valid:
  ```bash
  kubectl kustomize kustomize/airflow-test/ > /dev/null
  # No errors
  ```

---

## 🎯 Next Steps

After migration:

1. **Review changes**: `git diff kustomize/`
2. **Commit** (optional): `git commit -m "Migrate to br.icr.io/br-ibm-images"`
3. **Deploy** (when ready): `kubectl apply -k kustomize/airflow-test/`
4. **Monitor**: `kubectl get pods -n airflow-test`

---

**Ready?** Run the 5 commands above! 🚀

**Questions?**
- Creating namespace: See `SETUP_NAMESPACE.md`
- Understanding workflow: See `MIGRATION_WORKFLOW.md`
- JFrog setup: See config section above

---

**Created**: 2025-10-29
**Updated for**: Brazil region, single custom image, no public images
