# 🔄 Image Migration Workflow - Detailed Explanation

**IMPORTANT**: No images have been downloaded yet. Everything happens when YOU run the scripts.

---

## 📍 Current State (Before Running Scripts)

### Where Images Are NOW:

| Image | Current Location | Access |
|-------|-----------------|--------|
| `mmjc-airflow-service:latest` | `icr.io/mjc-cr/` | ✅ You have access (same account) |
| `milvus:v2.5.15` | `docker.io/milvusdb/` | ✅ Public |
| `etcd:3.5.18-r1` | `docker.io/milvusdb/` | ✅ Public |
| `kafka:3.1.0-debian-10-r52` | `docker.io/bitnami/` | ✅ Public |
| `zookeeper:3.7.0-debian-10-r320` | `docker.io/bitnami/` | ✅ Public |

### Where Images Will Go:

**Default Target**: `us.icr.io/mmjc-cr/` (same namespace, same account)

| Image | New Location |
|-------|--------------|
| `mmjc-airflow-service:latest` | `us.icr.io/mmjc-cr/mmjc-airflow-service:latest` |
| `milvus:v2.5.15` | `us.icr.io/mmjc-cr/milvus:v2.5.15` |
| `etcd:3.5.18-r1` | `us.icr.io/mmjc-cr/etcd:3.5.18-r1` |
| `kafka:3.1.0-debian-10-r52` | `us.icr.io/mmjc-cr/kafka:3.1.0-debian-10-r52` |
| `zookeeper:3.7.0-debian-10-r320` | `us.icr.io/mmjc-cr/zookeeper:3.7.0-debian-10-r320` |

---

## 🔄 What Happens When You Run `./scripts/migrate-images-manual.sh`

### Step-by-Step for EACH Image:

```
FOR EACH IMAGE:

┌─────────────────────────────────────────────────────────────┐
│ 1. PULL from SOURCE                                         │
│    Docker downloads image to LOCAL machine                  │
│    Location: Docker on Colima                               │
│                                                             │
│    Example:                                                 │
│    docker pull icr.io/mjc-cr/mmjc-airflow-service:latest   │
│                                                             │
│    Downloaded to: /Users/gregoriomomm/.colima/docker/...   │
│    Size on disk: ~2GB                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. TAG for TARGET                                           │
│    Creates a new tag pointing to same image                │
│    No data copied, just metadata                            │
│                                                             │
│    Example:                                                 │
│    docker tag \                                             │
│      icr.io/mjc-cr/mmjc-airflow-service:latest \           │
│      us.icr.io/mmjc-cr/mmjc-airflow-service:latest         │
│                                                             │
│    Now you have TWO tags for SAME image locally            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. PUSH to TARGET                                           │
│    Docker uploads image to target registry                  │
│    Destination: us.icr.io/mmjc-cr/...                      │
│                                                             │
│    Example:                                                 │
│    docker push us.icr.io/mmjc-cr/mmjc-airflow-service:latest│
│                                                             │
│    Uploaded to: IBM Container Registry (mmjc-cr namespace) │
└─────────────────────────────────────────────────────────────┘
```

### This Repeats 5 Times (for each image)

---

## 📂 Where Images Are During Migration

### 1. **Before Migration**:
```
SOURCE REGISTRIES (remote):
├── icr.io/mjc-cr/
│   └── mmjc-airflow-service:latest
├── docker.io/milvusdb/
│   ├── milvus:v2.5.15
│   └── etcd:3.5.18-r1
└── docker.io/bitnami/
    ├── kafka:3.1.0-debian-10-r52
    └── zookeeper:3.7.0-debian-10-r320

YOUR MACHINE (Colima):
└── (empty - no images yet)

TARGET REGISTRY (remote):
└── us.icr.io/mmjc-cr/
    └── (will be populated)
```

### 2. **During Migration** (after PULL, before PUSH):
```
SOURCE REGISTRIES (remote):
├── icr.io/mjc-cr/
│   └── mmjc-airflow-service:latest
└── (same as before)

YOUR MACHINE (Colima):
├── icr.io/mjc-cr/mmjc-airflow-service:latest      (~2GB on disk)
├── us.icr.io/mmjc-cr/mmjc-airflow-service:latest  (same data, just tagged)
├── milvusdb/milvus:v2.5.15                         (~1GB on disk)
├── us.icr.io/mmjc-cr/milvus:v2.5.15               (same data, just tagged)
└── ... (etc)

TARGET REGISTRY (remote):
└── us.icr.io/mmjc-cr/
    └── (being populated as script runs)
```

### 3. **After Migration** (after PUSH):
```
SOURCE REGISTRIES (remote):
└── (unchanged - original images still there)

YOUR MACHINE (Colima):
├── icr.io/mjc-cr/mmjc-airflow-service:latest      (~4-5GB total)
├── us.icr.io/mmjc-cr/mmjc-airflow-service:latest  (same images)
├── milvusdb/milvus:v2.5.15
├── us.icr.io/mmjc-cr/milvus:v2.5.15
└── ... (all 5 images, with 2 tags each)

TARGET REGISTRY (remote):
└── us.icr.io/mmjc-cr/
    ├── mmjc-airflow-service:latest        ✅ MIGRATED
    ├── milvus:v2.5.15                     ✅ MIGRATED
    ├── etcd:3.5.18-r1                     ✅ MIGRATED
    ├── kafka:3.1.0-debian-10-r52          ✅ MIGRATED
    └── zookeeper:3.7.0-debian-10-r320     ✅ MIGRATED
```

---

## 🎯 What Gets Updated After Migration

### When You Run `./scripts/update-image-refs.sh`:

This script updates **Kubernetes manifest files** to reference the NEW image locations.

### Files Updated:

#### 1. `kustomize/airflow-test/kustomization.yaml`

**BEFORE** (original):
```yaml
# No images section, uses original image references
# from base deployment files
```

**AFTER** (updated):
```yaml
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: us.icr.io/mmjc-cr/mmjc-airflow-service
    newTag: latest
  - name: quay.io/prometheus/statsd-exporter
    newName: quay.io/prometheus/statsd-exporter
    newTag: v0.28.0
```

#### 2. `kustomize/milvus-dev/kustomization.yaml` (or similar)

**BEFORE**:
```yaml
# No images section
```

**AFTER**:
```yaml
images:
  - name: milvusdb/milvus
    newName: us.icr.io/mmjc-cr/milvus
    newTag: v2.5.15
  - name: docker.io/milvusdb/etcd
    newName: us.icr.io/mmjc-cr/etcd
    newTag: 3.5.18-r1
  - name: docker.io/bitnami/kafka
    newName: us.icr.io/mmjc-cr/kafka
    newTag: 3.1.0-debian-10-r52
  - name: docker.io/bitnami/zookeeper
    newName: us.icr.io/mmjc-cr/zookeeper
    newTag: 3.7.0-debian-10-r320
```

### What This Means:

When Kubernetes reads these files, it will:
1. Find original image reference (e.g., `milvusdb/milvus:v2.5.15`)
2. Replace with new reference (e.g., `us.icr.io/mmjc-cr/milvus:v2.5.15`)
3. Pull from YOUR registry instead of Docker Hub

---

## 🔍 Verify Where Images Are

### Check Local Images (on your machine):
```bash
# After running migrate-images-manual.sh
docker images | grep -E "(milvus|kafka|zookeeper|etcd|airflow)"

# Expected output:
us.icr.io/mmjc-cr/mmjc-airflow-service   latest    abc123   2GB
icr.io/mjc-cr/mmjc-airflow-service       latest    abc123   2GB (same ID)
us.icr.io/mmjc-cr/milvus                 v2.5.15   def456   1GB
milvusdb/milvus                          v2.5.15   def456   1GB (same ID)
...
```

### Check Remote Registry (IBM CR):
```bash
# After migration completes
ibmcloud cr images --restrict mmjc-cr | grep -E "(milvus|kafka|zookeeper|etcd|airflow)"

# Expected output:
us.icr.io/mmjc-cr/mmjc-airflow-service   latest      ...
us.icr.io/mmjc-cr/milvus                 v2.5.15     ...
us.icr.io/mmjc-cr/etcd                   3.5.18-r1   ...
us.icr.io/mmjc-cr/kafka                  3.1.0...    ...
us.icr.io/mmjc-cr/zookeeper              3.7.0...    ...
```

### Check Updated References:
```bash
# After running update-image-refs.sh
grep -A 2 "newName:" kustomize/*/kustomization.yaml

# Expected output:
kustomize/airflow-test/kustomization.yaml:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: us.icr.io/mmjc-cr/mmjc-airflow-service
    newTag: latest

kustomize/milvus-dev/kustomization.yaml:
  - name: milvusdb/milvus
    newName: us.icr.io/mmjc-cr/milvus
    newTag: v2.5.15
...
```

---

## 💾 Disk Space Requirements

### On Your Local Machine (Colima):

**During migration** (temporary):
- 5 images × ~1GB avg = **~5GB**
- Plus 5 tags (same images) = **~5GB total**
- Plus Docker overhead = **~6-7GB needed**

**After migration** (if you keep images):
- **~5GB** (can be cleaned with `docker system prune -a`)

**Recommended**:
- **10GB free** before starting
- Clean up after: `docker system prune -a`

---

## 🎯 Summary - What Happens Where

```
┌────────────────────────────────────────────────────────────────┐
│ 1. YOU RUN SCRIPT                                              │
│    Location: Your terminal                                     │
│    Command: ./scripts/migrate-images-manual.sh                │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ 2. DOCKER PULLS IMAGES                                         │
│    From: icr.io/mjc-cr + docker.io (internet)                 │
│    To: Your Mac (via Colima)                                  │
│    Location: ~/.colima/docker/overlay2/...                    │
│    Size: ~5GB                                                  │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ 3. DOCKER TAGS IMAGES                                          │
│    From: original-registry/image:tag                           │
│    To: us.icr.io/mmjc-cr/image:tag                            │
│    Location: Still on your Mac (just metadata, no copy)       │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ 4. DOCKER PUSHES IMAGES                                        │
│    From: Your Mac (via Colima)                                │
│    To: us.icr.io/mmjc-cr (internet, IBM Cloud)                │
│    Size: ~5GB upload                                           │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ 5. YOU RUN UPDATE SCRIPT                                       │
│    Location: Your terminal                                     │
│    Command: ./scripts/update-image-refs.sh                    │
│    Updates: kustomize/*/kustomization.yaml files              │
└────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────────┐
│ 6. IMAGES NOW IN TARGET REGISTRY                              │
│    Location: us.icr.io/mmjc-cr (IBM Cloud)                    │
│    References: Updated in kustomization.yaml files             │
│    Ready: To deploy to Kubernetes                             │
└────────────────────────────────────────────────────────────────┘
```

---

## ✅ To Confirm Everything

### After migration, run these checks:

```bash
# 1. Check local images
docker images | wc -l
# Should show ~10 images (5 images × 2 tags each)

# 2. Check remote registry
ibmcloud cr images --restrict mmjc-cr | grep -E "(milvus|kafka|zookeeper|etcd|airflow)"
# Should show 5 new images

# 3. Check updated references
grep "us.icr.io/mmjc-cr" kustomize/*/kustomization.yaml
# Should show new image paths

# 4. Test Kubernetes build
kubectl kustomize kustomize/airflow-test/ | grep "image:"
# Should show images from us.icr.io/mmjc-cr
```

---

## 🧹 Cleanup After Migration

```bash
# Remove local copies (optional, saves ~5GB)
docker system prune -a

# WARNING: This removes ALL unused images
# Keep if you want to deploy immediately
# Remove if you need disk space
```

---

**Bottom Line**:
- ❌ NO images downloaded yet
- ✅ Script will download when YOU run it
- ✅ Will upload to `us.icr.io/mmjc-cr/`
- ✅ Will update all references in kustomization files
- ✅ Everything happens on your machine, pushed to IBM Cloud

**Ready to start?** → `cat START_HERE.md`
