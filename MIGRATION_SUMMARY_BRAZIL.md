# 📋 Migration Summary - Brazil Region

**Date**: 2025-10-29
**Target**: `br.icr.io/br-ibm-images/`
**Region**: Brazil (São Paulo)

---

## 🎯 What Changed

### Migration Target Updated:

| Aspect | OLD | NEW ✅ |
|--------|-----|--------|
| **Target Registry** | `us.icr.io/mmjc-cr` | `br.icr.io/br-ibm-images` |
| **Region** | US South | Brazil São Paulo |
| **Namespace** | mmjc-cr | br-ibm-images |
| **Images Count** | 5 images | 1 image |
| **Total Size** | ~5GB | ~2GB |
| **Public Images** | Migrate all | ❌ Don't migrate (licensing) |
| **Time** | 30-60 min | 5-10 min |

---

## 📦 Images Migration Plan

### ✅ WILL MIGRATE (Our Custom Images):

| Source | Target | Size | Reason |
|--------|--------|------|--------|
| `us.icr.io/mmjc-cr/mmjc-airflow-service:latest` | `br.icr.io/br-ibm-images/mmjc-airflow-service:latest` | ~2GB | **Our custom Airflow image** |

### ❌ NOT MIGRATING (Public Images - Licensing):

| Image | Registry | Reason |
|-------|----------|--------|
| `milvusdb/milvus:v2.5.15` | docker.io | Public - cannot redistribute |
| `milvusdb/etcd:3.5.18-r1` | docker.io | Public - cannot redistribute |
| `bitnami/kafka:3.1.0-debian-10-r52` | docker.io | Public - cannot redistribute |
| `bitnami/zookeeper:3.7.0-debian-10-r320` | docker.io | Public - cannot redistribute |
| `prometheus/statsd-exporter:v0.28.0` | quay.io | Public - cannot redistribute |

**Important**: These images will be pulled from their original public registries. No licensing issues.

---

## 🔧 JFrog Artifactory Support (Optional)

### Configuration:

If you use JFrog Artifactory as a proxy for IBM CR:

```bash
# config/migration.env
JFROG_PREFIX=artifactory.yourcompany.com/ibm-cr-remote/
JFROG_ENABLED=true
```

### Access Paths:

With JFrog configured, images are accessible via:

1. **Direct (IBM CR)**:
   ```
   br.icr.io/br-ibm-images/mmjc-airflow-service:latest
   ```

2. **Via JFrog** (if configured):
   ```
   artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-airflow-service:latest
   ```

### Prerequisites:

- JFrog Artifactory must have a **remote repository** configured for `br.icr.io`
- Repository name example: `ibm-cr-remote`
- URL: `https://br.icr.io`

---

## 📝 Updated Files

### Scripts:

1. **`scripts/migrate-images-manual.sh`**
   - ✅ Target: `br.icr.io/br-ibm-images`
   - ✅ Migrates only 1 custom image
   - ✅ Public images excluded
   - ✅ JFrog prefix support

2. **`scripts/update-image-refs.sh`**
   - ✅ Updates to Brazil registry
   - ✅ Preserves public image references
   - ✅ Comments explain licensing

3. **`scripts/setup-docker-colima.sh`**
   - ✅ No changes (still works)

### Configuration:

4. **`config/migration.env.example`**
   - ✅ Added `TARGET_ICR_REGION=br.icr.io`
   - ✅ Added `TARGET_NAMESPACE=br-ibm-images`
   - ✅ Added JFrog configuration
   - ✅ Updated comments

### Documentation:

5. **`START_HERE_UPDATED.md`** (NEW)
   - ✅ Updated quick start guide
   - ✅ Brazil region target
   - ✅ 1 image only
   - ✅ JFrog documentation

6. **`SETUP_NAMESPACE.md`** (NEW)
   - ✅ Instructions to create `br-ibm-images`
   - ✅ Permission requirements
   - ✅ Troubleshooting

7. **`MIGRATION_SUMMARY_BRAZIL.md`** (THIS FILE)
   - ✅ Summary of all changes

---

## 🚀 Migration Commands

### Full Process (5 steps):

```bash
# 0. (If needed) Create namespace - see SETUP_NAMESPACE.md
# Ask admin or use existing namespace with access

# 1. Navigate
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration

# 2. Setup Docker
source ./scripts/setup-docker-colima.sh

# 3. Login to Brazil registry
ibmcloud cr region-set br.icr.io
ibmcloud cr login

# 4. Migrate (only 1 image, ~5-10 min)
./scripts/migrate-images-manual.sh

# 5. Update manifests
./scripts/update-image-refs.sh
```

---

## ✅ Verification Commands

```bash
# 1. Check migrated image in target
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images

# Expected output:
# Repositório                                      Tag     ...
# br.icr.io/br-ibm-images/mmjc-airflow-service    latest  ...

# 2. Verify public images NOT in target
ibmcloud cr images --restrict br-ibm-images | grep -E "(milvus|kafka|zookeeper|etcd)"
# Expected: Empty (public images not migrated)

# 3. Check updated manifests
grep -A 5 "images:" kustomize/airflow-test/kustomization.yaml

# Expected:
# images:
#   - name: us.icr.io/mmjc-cr/mmjc-airflow-service
#     newName: br.icr.io/br-ibm-images/mmjc-airflow-service
#     newTag: latest

# 4. Test Kubernetes build
kubectl kustomize kustomize/airflow-test/ | grep "image:" | sort -u

# Expected mix:
#   image: br.icr.io/br-ibm-images/mmjc-airflow-service:latest
#   image: docker.io/milvusdb/milvus:v2.5.15
#   image: docker.io/bitnami/kafka:3.1.0-debian-10-r52
#   (etc - public images from original registries)
```

---

## 🏗️ Architecture After Migration

```
┌────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                      │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ AIRFLOW (namespace: airflow-test)                    │ │
│  │                                                      │ │
│  │ Uses images from:                                    │ │
│  │ • br.icr.io/br-ibm-images/mmjc-airflow-service ✅   │ │
│  │   (OUR custom image - in Brazil)                    │ │
│  │                                                      │ │
│  │ • quay.io/prometheus/statsd-exporter                │ │
│  │   (public - from quay.io)                           │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ MILVUS (namespace: mmjc-test)                         │ │
│  │                                                      │ │
│  │ Uses images from PUBLIC registries:                 │ │
│  │ • docker.io/milvusdb/milvus:v2.5.15                 │ │
│  │ • docker.io/milvusdb/etcd:3.5.18-r1                 │ │
│  │ • docker.io/bitnami/kafka:3.1.0...                  │ │
│  │ • docker.io/bitnami/zookeeper:3.7.0...              │ │
│  │                                                      │ │
│  │ (All pulled from Docker Hub - no licensing issues)  │ │
│  └──────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘

                          REGISTRIES

┌─────────────────────────────────────────────────────────┐
│ OUR IMAGES (Brazil)                                     │
│ br.icr.io/br-ibm-images/                                │
│   └── mmjc-airflow-service:latest                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PUBLIC IMAGES (Docker Hub / Quay.io)                    │
│ docker.io/                                              │
│   ├── milvusdb/milvus:v2.5.15                           │
│   ├── milvusdb/etcd:3.5.18-r1                           │
│   ├── bitnami/kafka:3.1.0-debian-10-r52                 │
│   └── bitnami/zookeeper:3.7.0-debian-10-r320            │
│ quay.io/                                                │
│   └── prometheus/statsd-exporter:v0.28.0                │
└─────────────────────────────────────────────────────────┘

        (Optional: JFrog Artifactory as Proxy)
┌─────────────────────────────────────────────────────────┐
│ artifactory.company.com/ibm-cr-remote/                  │
│   └── br-ibm-images/mmjc-airflow-service:latest         │
│       (mirrors br.icr.io)                               │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Before vs After

### BEFORE Migration:

```
us.icr.io/mmjc-cr/                      (US Region)
└── mmjc-airflow-service:latest         ← Source

docker.io/                              (Public)
├── milvusdb/milvus:v2.5.15
├── milvusdb/etcd:3.5.18-r1
├── bitnami/kafka:3.1.0...
└── bitnami/zookeeper:3.7.0...

Kubernetes: Points to US registry for custom images
```

### AFTER Migration:

```
br.icr.io/br-ibm-images/                (Brazil Region)
└── mmjc-airflow-service:latest         ✅ Migrated

us.icr.io/mmjc-cr/                      (US Region)
└── mmjc-airflow-service:latest         (can be deleted after verification)

docker.io/                              (Public - unchanged)
├── milvusdb/milvus:v2.5.15
├── milvusdb/etcd:3.5.18-r1
├── bitnami/kafka:3.1.0...
└── bitnami/zookeeper:3.7.0...

Kubernetes: Points to Brazil registry for custom images
            Points to Docker Hub for public images
```

---

## 💾 Disk Space

### Local (Your Mac):
- **During migration**: ~2-3GB (1 image pulled + tagged)
- **After migration**: Can clean with `docker system prune -a`

### IBM Container Registry:
- **Brazil region**: ~2GB (1 image)
- **Cost**: Free tier = 500MB, then $0.50/GB-month

---

## 🎯 Success Criteria

After migration, all must be TRUE:

- ✅ Namespace `br-ibm-images` exists in Brazil region
- ✅ 1 image in target: `mmjc-airflow-service:latest`
- ✅ 0 public images in target (licensing compliance)
- ✅ Kustomization files updated to Brazil registry
- ✅ Public images still reference Docker Hub
- ✅ `kubectl kustomize` builds without errors
- ✅ Can pull image: `docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest`

---

## 🔒 Licensing Compliance

### Why We Don't Migrate Public Images:

1. **Milvus** (Apache 2.0): Can use, but not redistribute in our private registry
2. **Bitnami** (Apache 2.0 + Bitnami terms): Can use from Docker Hub
3. **StatsD Exporter** (Apache 2.0): Can use from Quay.io

**Solution**: Pull directly from official public registries. No licensing issues.

### Our Custom Images:

- **mmjc-airflow-service**: We built it, we own it, we can migrate it ✅

---

## 📚 Documentation Index

| File | Purpose | Read When |
|------|---------|-----------|
| **START_HERE_UPDATED.md** | Quick start | Starting migration |
| **SETUP_NAMESPACE.md** | Create namespace | Before migration |
| **MIGRATION_SUMMARY_BRAZIL.md** | This file | Understanding changes |
| **MIGRATION_WORKFLOW.md** | Detailed flow | Troubleshooting |
| **SERVICES_AND_IMAGES_GUIDE.md** | Architecture | Understanding system |

---

## 🆘 Common Issues

### Issue: Cannot create namespace

**Solution**: Ask admin or use existing namespace. See `SETUP_NAMESPACE.md`

### Issue: Public images failing to pull

**Solution**: Normal! They should pull from docker.io/quay.io, not br.icr.io

### Issue: Want to add more custom images

**Solution**: Edit `scripts/migrate-images-manual.sh`, add to `IMAGES` array:
```bash
IMAGES=(
    "us.icr.io/mmjc-cr/mmjc-airflow-service:latest|mmjc-airflow-service|latest"
    "us.icr.io/mmjc-cr/your-custom-image:v1.0|your-custom-image|v1.0"  # ADD HERE
)
```

---

## ✅ Ready to Migrate

Everything is configured and ready:

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
ibmcloud cr region-set br.icr.io
ibmcloud cr login
./scripts/migrate-images-manual.sh
./scripts/update-image-refs.sh
```

**Time**: 5-10 minutes
**Size**: ~2GB download + upload
**Result**: 1 custom image in Brazil region ✅

---

**Questions?** See `START_HERE_UPDATED.md` for detailed walkthrough
