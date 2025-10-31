# 🚀 Quick Start: Manual Image Migration

**Using**: IBM Cloud CLI + Docker (Colima)
**Date**: 2025-10-29

---

## ✅ Prerequisites Check

```bash
# 1. Check Colima is running
colima status
# Should show: "colima is running"

# 2. Check IBM Cloud CLI
ibmcloud --version
ibmcloud target

# 3. Check Docker context
docker context use colima
docker ps
```

If Colima is not running:
```bash
colima start
```

---

## 🎯 Step-by-Step Migration

### Step 1: Prepare Environment

```bash
# Navigate to project
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration

# Verify scripts exist
ls -la scripts/migrate-images-manual.sh
ls -la scripts/update-image-refs.sh
```

### Step 2: Configure Target Registry

Choose your target registry:

#### Option A: Use Current IBM ICR (mmjc-cr namespace)
```bash
# Check current setup
ibmcloud cr region
ibmcloud cr namespaces

# Export (already set as default in script)
export TARGET_REGISTRY="us.icr.io/mmjc-cr"
```

#### Option B: Create New IBM ICR Namespace (Itaú)
```bash
# Login to Itaú account (if needed)
~/ibm-login-itau

# Create new namespace
ibmcloud cr namespace-add itau-migration

# Set as target
export TARGET_REGISTRY="us.icr.io/itau-migration"
```

#### Option C: Use AWS ECR
```bash
# Set AWS credentials
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=123456789012

# Set target
export TARGET_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Make sure AWS CLI is configured
aws sts get-caller-identity
```

### Step 3: Run Migration Script

```bash
# Dry run first (optional - check script)
cat scripts/migrate-images-manual.sh

# Run migration
./scripts/migrate-images-manual.sh
```

**What it does**:
1. ✅ Sets up Docker context (Colima)
2. ✅ Checks IBM Cloud CLI
3. ✅ Logs into registries
4. ✅ Pulls 5 images from source
5. ✅ Tags for target registry
6. ✅ Pushes to target
7. ✅ Shows summary

**Expected output**:
```
========================================
🐳 Image Migration Script
========================================

[1/7] Setting up Docker context...
✅ Docker is working via Colima

[2/7] Checking IBM Cloud CLI...
✅ IBM Cloud CLI: ibmcloud 2.37.1

[3/7] Determining target registry...
   Target Registry: us.icr.io/mmjc-cr

[4/7] Logging into registries...
✅ Logged into registries

[5/7] Defining images to migrate...
   Found 5 images to migrate

[6/7] Migrating images...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: icr.io/mjc-cr/mmjc-airflow-service:latest
   → Target: us.icr.io/mmjc-cr/mmjc-airflow-service:latest

   [1/3] Pulling source image...
   ✅ Pull successful
   [2/3] Tagging image...
   ✅ Tagged
   [3/3] Pushing to target registry...
   ✅ Push successful

... (repeats for 5 images) ...

========================================
📊 Migration Summary
========================================

✅ Successfully migrated: 5
⚠️  Skipped (already exist): 0
❌ Failed: 0

🎉 Migration completed successfully!
```

### Step 4: Update Kustomization Files

```bash
# Update image references in Kubernetes manifests
./scripts/update-image-refs.sh
```

**What it does**:
- Updates `kustomize/airflow-test/kustomization.yaml`
- Updates `kustomize/milvus/kustomization.yaml` (if exists)
- Adds `images:` section with new registry paths

### Step 5: Verify Changes

```bash
# Check what changed
git diff kustomize/

# Test kustomize build (dry run)
kubectl kustomize kustomize/airflow-test/ > /tmp/airflow-test.yaml
kubectl kustomize kustomize/milvus-dev/ > /tmp/milvus-dev.yaml

# Verify images in generated manifests
grep "image:" /tmp/airflow-test.yaml
grep "image:" /tmp/milvus-dev.yaml
```

### Step 6: Deploy (When Ready)

```bash
# Deploy Airflow
kubectl apply -k kustomize/airflow-test/

# Deploy Milvus
kubectl apply -k kustomize/milvus-dev/

# Check pods are pulling from new registry
kubectl get pods -n airflow-test -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n'
kubectl get pods -n mmjc-test -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n'
```

---

## 🔍 Troubleshooting

### Issue: Docker daemon not running

```bash
# Check Colima status
colima status

# If not running
colima start

# Set Docker context
docker context use colima
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

# Test
docker ps
```

### Issue: Cannot pull from icr.io/mjc-cr

```bash
# Check IBM Cloud login
ibmcloud target

# Re-login to container registry
ibmcloud cr login

# Test manual pull
docker pull icr.io/mjc-cr/mmjc-airflow-service:latest
```

### Issue: Cannot push to target registry

```bash
# For IBM ICR
ibmcloud cr login

# Check namespace exists
ibmcloud cr namespace-list

# Check quota
ibmcloud cr quota

# For AWS ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Create repository if needed
aws ecr create-repository --repository-name mmjc-airflow-service
```

### Issue: Image already exists

```bash
# Skip - script automatically skips existing images
# Or delete and re-push:
ibmcloud cr image-rm us.icr.io/mmjc-cr/image-name:tag

# For AWS ECR
aws ecr batch-delete-image \
    --repository-name image-name \
    --image-ids imageTag=tag
```

---

## 📋 Images Being Migrated

| Source | Target | Size | Priority |
|--------|--------|------|----------|
| `icr.io/mjc-cr/mmjc-airflow-service:latest` | `${TARGET}/mmjc-airflow-service:latest` | ~2GB | 🔴 HIGH |
| `milvusdb/milvus:v2.5.15` | `${TARGET}/milvus:v2.5.15` | ~1GB | 🔴 HIGH |
| `docker.io/milvusdb/etcd:3.5.18-r1` | `${TARGET}/etcd:3.5.18-r1` | ~150MB | 🔴 HIGH |
| `docker.io/bitnami/kafka:3.1.0-debian-10-r52` | `${TARGET}/kafka:3.1.0-debian-10-r52` | ~500MB | 🔴 HIGH |
| `docker.io/bitnami/zookeeper:3.7.0-debian-10-r320` | `${TARGET}/zookeeper:3.7.0-debian-10-r320` | ~300MB | 🔴 HIGH |

**Total**: ~4-5GB download + 4-5GB upload

**Time estimate**: 30-60 minutes (depends on network speed)

---

## 🎯 Current Environment Info

```bash
# IBM Cloud
Account: iseaitools (16bed81d1ae040c5bc9d55b6507ebdda)
Region: us-south
Registry: us.icr.io
Namespace: mmjc-cr

# Docker
Runtime: Colima (macOS Virtualization Framework)
Version: Docker 28.1.1
Socket: unix:///Users/gregoriomomm/.colima/default/docker.sock
```

---

## 💡 Tips

1. **Network**: Migration requires good internet (4-5GB download + upload)
2. **Disk Space**: Ensure 10GB free space for Docker images
3. **Parallel**: Script runs sequentially; for faster migration use `skopeo` (commented in main script)
4. **Cleanup**: After successful deployment, clean old local images:
   ```bash
   docker system prune -a
   ```

5. **Monitoring**: Watch migration progress:
   ```bash
   # In another terminal
   watch -n 2 "docker images | head -20"
   ```

---

## ✅ Success Criteria

- [ ] All 5 images migrated successfully
- [ ] Kustomization files updated
- [ ] `kubectl kustomize` builds without errors
- [ ] New images pullable from target registry
- [ ] Pods start successfully with new images

---

**Next**: See `SERVICES_AND_IMAGES_GUIDE.md` for complete architecture details
