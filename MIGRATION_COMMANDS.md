# 🚀 Migration Commands - Quick Reference

**Ready to run**: Copy-paste these commands

---

## 🎯 COMPLETE MIGRATION (5 Commands)

```bash
# 1. Navigate to project
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration

# 2. Setup Docker with Colima
source ./scripts/setup-docker-colima.sh

# 3. Login to IBM Cloud (if needed)
ibmcloud login --sso
ibmcloud target -g mjc

# 4. Run migration (this is the long-running process)
./scripts/migrate-images-manual.sh

# 5. Update Kubernetes manifests
./scripts/update-image-refs.sh
```

**Time**: 30-60 minutes (step 4 takes most time)

---

## 📝 Step-by-Step with Explanations

### Step 1: Setup Environment

```bash
# Go to project directory
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration

# Verify you're in the right place
pwd
ls -la scripts/
```

### Step 2: Setup Docker

```bash
# This sets up Docker to use Colima
source ./scripts/setup-docker-colima.sh

# Expected output:
# ✅ Colima Status: running
# ✅ Set DOCKER_HOST=...
# ✅ Docker is working!
```

### Step 3: Login to IBM Cloud (if needed)

```bash
# Check current login
ibmcloud target

# If not logged in or wrong account:
ibmcloud login --sso

# Set target resource group
ibmcloud target -g mjc

# Login to container registry
ibmcloud cr login

# Verify
ibmcloud cr namespaces
# Should show: mmjc-cr
```

### Step 4: Choose Target Registry

#### Option A: Use Current Namespace (mmjc-cr) - DEFAULT
```bash
# Already configured in script
# Target: us.icr.io/mmjc-cr
```

#### Option B: Create New Namespace
```bash
# Create new namespace
ibmcloud cr namespace-add itau-migration

# Set as target
export TARGET_REGISTRY="us.icr.io/itau-migration"
```

#### Option C: Use AWS ECR
```bash
# Set AWS target
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=123456789012
export TARGET_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${TARGET_REGISTRY}

# Create repositories
aws ecr create-repository --repository-name mmjc-airflow-service
aws ecr create-repository --repository-name milvus
aws ecr create-repository --repository-name etcd
aws ecr create-repository --repository-name kafka
aws ecr create-repository --repository-name zookeeper
```

### Step 5: Run Migration (THE LONG PROCESS)

```bash
# Run the migration script
./scripts/migrate-images-manual.sh

# This will:
# 1. Pull 5 images from source (~4-5GB download)
# 2. Tag them for target registry
# 3. Push to target registry (~4-5GB upload)
#
# Estimated time: 30-60 minutes
```

**What's happening**:
```
[6/7] Migrating images...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: icr.io/mjc-cr/mmjc-airflow-service:latest
   [1/3] Pulling source image... (~2GB)
   [2/3] Tagging image...
   [3/3] Pushing to target registry... (~2GB)

... repeats 4 more times ...

📊 Migration Summary
✅ Successfully migrated: 5
```

### Step 6: Update Kubernetes Manifests

```bash
# Update image references in kustomization files
./scripts/update-image-refs.sh

# Verify changes
git diff kustomize/
```

### Step 7: Validate (Before Deploy)

```bash
# Test kustomize build
kubectl kustomize kustomize/airflow-test/ > /tmp/airflow-test.yaml
kubectl kustomize kustomize/milvus-dev/ > /tmp/milvus-dev.yaml

# Check images in generated manifests
echo "=== Airflow Images ==="
grep "image:" /tmp/airflow-test.yaml | sort -u

echo "=== Milvus Images ==="
grep "image:" /tmp/milvus-dev.yaml | sort -u

# Should show images from TARGET_REGISTRY
```

---

## 🔍 Monitoring Commands (Run in Another Terminal)

```bash
# Watch Docker images being pulled/pushed
watch -n 2 "docker images | head -20"

# Watch disk space
watch -n 5 "df -h | grep -E '(Filesystem|/Users)'"

# Watch network (macOS)
nettop -P -J bytes_in,bytes_out -x -L 1 | head -10
```

---

## 🛠️ Troubleshooting Commands

### Docker Not Working

```bash
# Check Colima
colima status

# If not running
colima start

# Reset Docker context
unset DOCKER_HOST
docker context use colima
docker ps
```

### Pull Fails

```bash
# Re-login to IBM CR
ibmcloud cr login

# Test manual pull
docker pull icr.io/mjc-cr/mmjc-airflow-service:latest

# Check if image exists
ibmcloud cr images --restrict mmjc-cr | grep mmjc-airflow-service
```

### Push Fails

```bash
# Check target registry access
ibmcloud cr login

# Check quota
ibmcloud cr quota

# List repositories
ibmcloud cr images --restrict mmjc-cr

# For AWS ECR
aws ecr describe-repositories
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
```

### Out of Disk Space

```bash
# Check space
df -h

# Clean Docker
docker system prune -a

# Free up space
rm -rf ~/Library/Caches/Docker
colima delete && colima start
```

---

## 📊 Progress Tracking

```bash
# List migrated images in target registry
ibmcloud cr images --restrict mmjc-cr

# Expected after successful migration:
# - mmjc-airflow-service:latest
# - milvus:v2.5.15
# - etcd:3.5.18-r1
# - kafka:3.1.0-debian-10-r52
# - zookeeper:3.7.0-debian-10-r320
```

---

## ✅ Success Check

```bash
# All checks should pass:

# 1. Colima running
colima status | grep running

# 2. Docker working
docker ps

# 3. IBM Cloud logged in
ibmcloud target | grep Account

# 4. Images in target registry
ibmcloud cr images --restrict mmjc-cr | wc -l
# Should show at least 5 new images

# 5. Kustomization updated
grep "newName:" kustomize/airflow-test/kustomization.yaml
grep "newName:" kustomize/milvus-dev/kustomization.yaml
```

---

## 🎯 Current Setup Info

```
IBM Cloud:
  Account: iseaitools (16bed81d1ae040c5bc9d55b6507ebdda)
  Region: us-south
  Registry: us.icr.io
  Namespace: mmjc-cr

Docker:
  Runtime: Colima (macOS Virtualization)
  Version: 28.1.1
  Socket: ~/.colima/default/docker.sock

Target Registry (default):
  us.icr.io/mmjc-cr
```

---

## 💾 Backup Before Migration

```bash
# Optional: Backup current kustomization files
cp kustomize/airflow-test/kustomization.yaml kustomize/airflow-test/kustomization.yaml.backup
cp kustomize/milvus-dev/kustomization.yaml kustomize/milvus-dev/kustomization.yaml.backup
```

---

**Need help?** Check:
- `QUICKSTART_MANUAL_MIGRATION.md` - Detailed guide
- `SERVICES_AND_IMAGES_GUIDE.md` - Architecture details
- `DEPLOYMENT.md` - Deployment guide
