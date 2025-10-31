# 🚀 START HERE - Image Migration Guide

**Status**: Ready to run ✅
**Tools**: IBM Cloud CLI + Docker (Colima)
**Time**: 30-60 minutes

---

## ⚡ QUICK START (5 Commands)

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
ibmcloud cr login
./scripts/migrate-images-manual.sh
./scripts/update-image-refs.sh
```

**That's it!** ✅

---

## 📚 Documentation Files

| File | Description | When to Read |
|------|-------------|--------------|
| **`START_HERE.md`** | This file - Quick overview | Read first |
| **`MIGRATION_COMMANDS.md`** | Copy-paste commands | Running migration |
| **`QUICKSTART_MANUAL_MIGRATION.md`** | Detailed step-by-step | Troubleshooting |
| **`SERVICES_AND_IMAGES_GUIDE.md`** | Architecture + GenAI setup | Understanding system |
| **`DEPLOYMENT.md`** | Deployment guide | After migration |

---

## 🎯 What You're Migrating

### Images (5 total):
1. **mmjc-airflow-service** (~2GB) - Airflow custom image
2. **milvus** (~1GB) - Vector database
3. **etcd** (~150MB) - Metadata store
4. **kafka** (~500MB) - Message queue
5. **zookeeper** (~300MB) - Kafka coordinator

**Total**: ~4-5GB to download + upload

### From → To:
```
icr.io/mjc-cr/...                → us.icr.io/mmjc-cr/...
docker.io/milvusdb/...           → us.icr.io/mmjc-cr/...
docker.io/bitnami/...            → us.icr.io/mmjc-cr/...
```

---

## ✅ Prerequisites

### Already Installed:
- ✅ IBM Cloud CLI 2.37.1
- ✅ Docker (via Colima)
- ✅ Colima running
- ✅ Logged into IBM Cloud (iseaitools account)
- ✅ Access to mmjc-cr namespace

### Check:
```bash
colima status              # Should show "running"
ibmcloud target            # Should show iseaitools
docker context use colima  # Switch to Colima
docker ps                  # Should work
```

---

## 🎬 Step-by-Step

### 1️⃣ Setup Docker (1 minute)

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
```

**Expected output**:
```
✅ Colima Status: running
✅ Docker is working!
🎉 Docker is ready for migration!
```

### 2️⃣ Login to IBM Registry (30 seconds)

```bash
ibmcloud cr login
```

**Expected output**:
```
Logging in to 'us.icr.io'...
Logged in to 'us.icr.io'.
OK
```

### 3️⃣ Run Migration (30-60 minutes) ⏰

```bash
./scripts/migrate-images-manual.sh
```

**This is the long-running part**. It will:
- Pull 5 images from source (~4-5GB download)
- Tag them for target registry
- Push to target (~4-5GB upload)

**Expected output**:
```
[6/7] Migrating images...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: icr.io/mjc-cr/mmjc-airflow-service:latest
   [1/3] Pulling source image...
   ✅ Pull successful (2 minutes)
   [2/3] Tagging image...
   ✅ Tagged
   [3/3] Pushing to target registry...
   ✅ Push successful (2 minutes)

... repeats 4 more times ...

📊 Migration Summary
✅ Successfully migrated: 5
🎉 Migration completed successfully!
```

**💡 Tip**: Open another terminal and run `watch -n 2 "docker images | head -20"` to monitor progress

### 4️⃣ Update Kubernetes Manifests (10 seconds)

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

### 5️⃣ Verify (30 seconds)

```bash
# Check what changed
git diff kustomize/

# Test kustomize build
kubectl kustomize kustomize/airflow-test/ > /tmp/airflow-test.yaml
kubectl kustomize kustomize/milvus-dev/ > /tmp/milvus-dev.yaml

# Verify images
grep "image:" /tmp/airflow-test.yaml | sort -u
grep "image:" /tmp/milvus-dev.yaml | sort -u
```

**Expected**: All images should point to `us.icr.io/mmjc-cr/...`

---

## 🎉 Success Criteria

After successful migration, you should have:

- ✅ 5 images in `us.icr.io/mmjc-cr/`:
  ```bash
  ibmcloud cr images --restrict mmjc-cr
  ```

- ✅ Updated kustomization files:
  ```bash
  grep "newName:" kustomize/*/kustomization.yaml
  ```

- ✅ Valid Kubernetes manifests:
  ```bash
  kubectl kustomize kustomize/airflow-test/ > /dev/null
  kubectl kustomize kustomize/milvus-dev/ > /dev/null
  ```

---

## 🚫 What NOT to Do

- ❌ Don't interrupt migration mid-pull/push
- ❌ Don't close terminal during migration
- ❌ Don't run multiple migrations in parallel
- ❌ Don't delete source images before verifying

---

## 🆘 Troubleshooting

### "Docker daemon not running"
```bash
colima start
source ./scripts/setup-docker-colima.sh
```

### "Cannot pull from icr.io/mjc-cr"
```bash
ibmcloud login --sso
ibmcloud target -g mjc
ibmcloud cr login
```

### "Out of disk space"
```bash
df -h
docker system prune -a
```

### "Image already exists"
```bash
# Skip - this is fine, script continues
```

**More help**: See `QUICKSTART_MANUAL_MIGRATION.md` section "Troubleshooting"

---

## 📊 Migration Progress

You can check progress anytime:

```bash
# In target registry
ibmcloud cr images --restrict mmjc-cr | grep -E "(milvus|kafka|zookeeper|etcd|airflow)"

# Local Docker
docker images | grep -E "(milvus|kafka|zookeeper|etcd|airflow)"

# Disk space
df -h | grep /Users
```

---

## 🔄 What Happens Next

After migration completes:

1. **Review changes**:
   ```bash
   git diff
   ```

2. **Commit updates** (optional):
   ```bash
   git add kustomize/
   git commit -m "Update image references to us.icr.io/mmjc-cr"
   ```

3. **Deploy** (when ready):
   ```bash
   kubectl apply -k kustomize/airflow-test/
   kubectl apply -k kustomize/milvus-dev/
   ```

4. **Verify pods**:
   ```bash
   kubectl get pods -n airflow-test
   kubectl get pods -n mmjc-test
   ```

---

## 🎯 Current Environment

```
IBM Cloud Account:
  Name: iseaitools
  ID: 16bed81d1ae040c5bc9d55b6507ebdda
  Region: us-south
  Resource Group: mjc

Registry:
  URL: us.icr.io
  Namespace: mmjc-cr

Docker:
  Runtime: Colima (macOS Virtualization)
  Version: 28.1.1
  Socket: ~/.colima/default/docker.sock
```

---

## 📋 Scripts Created

| Script | Purpose | Run Time |
|--------|---------|----------|
| `setup-docker-colima.sh` | Setup Docker context | 10s |
| `migrate-images-manual.sh` | Migrate all images | 30-60min |
| `update-image-refs.sh` | Update manifests | 10s |

---

## 💡 Pro Tips

1. **Network**: Run during good internet hours (4-5GB upload/download)
2. **Monitor**: Use `watch` command to see progress
3. **Disk Space**: Ensure 10GB free before starting
4. **Backup**: Kustomization files backed up automatically by git
5. **Parallel**: Don't run multiple migrations - sequential is safer

---

## ❓ Questions?

- **What's being migrated?** → See `SERVICES_AND_IMAGES_GUIDE.md`
- **How do I configure GenAI/Bedrock?** → See `SERVICES_AND_IMAGES_GUIDE.md` section 3
- **What services need AWS?** → See `SERVICES_AND_IMAGES_GUIDE.md` section 2
- **Detailed commands?** → See `MIGRATION_COMMANDS.md`
- **Deployment?** → See `DEPLOYMENT.md`

---

## 🚀 Ready? Let's Go!

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
ibmcloud cr login
./scripts/migrate-images-manual.sh
```

**Good luck!** 🍀

---

**Created**: 2025-10-29
**Status**: Ready to run ✅
