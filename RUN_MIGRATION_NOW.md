# ✅ READY TO MIGRATE - You Have Access!

**Status**: ✅ All prerequisites met
**Namespace**: `br-ibm-images` exists and you have access
**Account**: iseaitools (16bed81d1ae040c5bc9d55b6507ebdda)
**Region**: Brazil (br.icr.io)

---

## ✅ Verified Prerequisites

```
✅ IBM Cloud CLI logged in
✅ Account: iseaitools iseaitools's Account
✅ Brazil region configured (br.icr.io)
✅ Namespace exists: br-ibm-images
✅ You have access to namespace
✅ Existing image found: mjc-mermaid-validator:1.0.17
```

---

## 🚀 RUN MIGRATION NOW (3 Simple Commands)

```bash
# 1. Setup Docker with Colima
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh

# 2. Run migration (migrates mmjc-airflow-service to Brazil)
./scripts/migrate-images-manual.sh

# 3. Update Kubernetes manifests
./scripts/update-image-refs.sh
```

**Time**: 5-10 minutes
**Size**: ~2GB (1 image)

---

## 📦 What Will Be Migrated

### Source (US Region):
```
us.icr.io/mmjc-cr/mmjc-airflow-service:latest  (~2GB)
```

### Target (Brazil Region):
```
br.icr.io/br-ibm-images/mmjc-airflow-service:latest  ✅
```

### Already in Target:
```
br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17  (existing)
```

---

## 📋 Step-by-Step

### Step 1: Setup Docker

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
```

**Expected output**:
```
🐳 Setting up Docker with Colima...
✅ Colima Status: running
✅ Docker is working!
🎉 Docker is ready for migration!
```

### Step 2: Run Migration

```bash
./scripts/migrate-images-manual.sh
```

**What happens**:
```
[1/7] Setting up Docker context... ✅
[2/7] Checking IBM Cloud CLI... ✅
[3/7] Determining target registry...
      Target Registry: br.icr.io/br-ibm-images
[4/7] Logging into registries... ✅
[5/7] Defining images to migrate...
      Found 1 images to migrate
[6/7] Migrating images...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: us.icr.io/mmjc-cr/mmjc-airflow-service:latest
   → Target: br.icr.io/br-ibm-images/mmjc-airflow-service:latest

   [1/3] Pulling source image... (~2 min)
   ✅ Pull successful
   [2/3] Tagging image...
   ✅ Tagged
   [3/3] Pushing to target registry... (~2 min)
   ✅ Push successful

[7/7] Migration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Successfully migrated: 1
⚠️  Skipped (already exist): 0
❌ Failed: 0

🎉 Migration completed successfully!
```

### Step 3: Update Manifests

```bash
./scripts/update-image-refs.sh
```

**Expected output**:
```
[1/2] Updating Airflow kustomization...
   ✅ Updated kustomize/airflow-test/kustomization.yaml

[2/2] Updating Milvus kustomization...
   ✅ Updated kustomize/milvus-dev/kustomization.yaml

✅ Image references updated!
```

---

## ✅ Verification After Migration

```bash
# 1. Check images in Brazil registry
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images

# Expected output:
# br.icr.io/br-ibm-images/mjc-mermaid-validator    1.0.17   (existing)
# br.icr.io/br-ibm-images/mmjc-airflow-service     latest   (NEW!)

# 2. Check updated manifests
grep "br.icr.io/br-ibm-images" kustomize/airflow-test/kustomization.yaml

# Expected:
#   newName: br.icr.io/br-ibm-images/mmjc-airflow-service

# 3. Test Kubernetes build
kubectl kustomize kustomize/airflow-test/ | grep -E "image:" | sort -u

# Expected:
#   image: br.icr.io/br-ibm-images/mmjc-airflow-service:latest  (NEW)
#   image: docker.io/milvusdb/milvus:v2.5.15  (public)
#   image: docker.io/bitnami/kafka:...  (public)
#   (etc)
```

---

## 🎯 After Migration

### Review Changes:
```bash
git diff kustomize/
```

### Commit (optional):
```bash
git add kustomize/
git commit -m "Migrate Airflow image to br.icr.io/br-ibm-images"
```

### Deploy (when ready):
```bash
# Airflow
kubectl apply -k kustomize/airflow-test/

# Milvus
kubectl apply -k kustomize/milvus-dev/

# Monitor
kubectl get pods -n airflow-test
kubectl get pods -n mmjc-dev
```

---

## 📊 Current State

### Your Brazil Registry:

```
br.icr.io/br-ibm-images/
├── mjc-mermaid-validator:1.0.17  (existing - 68 MB)
└── (will add) mmjc-airflow-service:latest  (~2 GB)
```

### Public Images (NOT migrated):

```
docker.io/
├── milvusdb/milvus:v2.5.15
├── milvusdb/etcd:3.5.18-r1
├── bitnami/kafka:3.1.0-debian-10-r52
└── bitnami/zookeeper:3.7.0-debian-10-r320

quay.io/
└── prometheus/statsd-exporter:v0.28.0
```

---

## 🔍 Monitoring Progress

Open a second terminal and run:

```bash
# Watch Docker images
watch -n 2 "docker images | head -15"

# Watch network (macOS)
nettop -P -J bytes_in,bytes_out -x -L 1 | head -10

# Watch disk space
watch -n 5 "df -h | grep /Users"
```

---

## 💾 Cleanup After Migration

```bash
# Remove local Docker images to free space (optional)
docker system prune -a

# WARNING: This removes ALL unused images
# Wait until after you've verified deployment works
```

---

## 🆘 If Something Goes Wrong

### Migration Script Fails

**Check**:
```bash
# Docker working?
docker ps

# IBM Cloud logged in?
ibmcloud target

# Access to both regions?
ibmcloud cr region-set us.icr.io && ibmcloud cr images --restrict mmjc-cr | head -5
ibmcloud cr region-set br.icr.io && ibmcloud cr images --restrict br-ibm-images | head -5
```

### Image Already Exists

```bash
# Check if image already migrated
ibmcloud cr images --restrict br-ibm-images | grep mmjc-airflow-service

# If already exists, skip migration or delete and re-migrate:
ibmcloud cr image-rm br.icr.io/br-ibm-images/mmjc-airflow-service:latest
```

### Out of Disk Space

```bash
# Check space
df -h

# Clean Docker
docker system prune -a

# Restart Colima with more space
colima stop
colima start --disk 100
```

---

## ✅ Success Checklist

After running all 3 commands:

- [ ] Docker setup successful
- [ ] Migration completed (1 image migrated)
- [ ] No errors in migration output
- [ ] Manifests updated
- [ ] Image visible in `ibmcloud cr images --restrict br-ibm-images`
- [ ] `kubectl kustomize` builds without errors
- [ ] Can pull image: `docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest`

---

## 🎉 You're Ready!

Everything is configured. Just run:

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
./scripts/migrate-images-manual.sh
./scripts/update-image-refs.sh
```

**Go for it!** 🚀
