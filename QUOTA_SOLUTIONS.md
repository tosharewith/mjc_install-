# 🔧 IBM Container Registry Quota Solutions

**Problem**: Account has exceeded 512 MB storage quota (currently using 568 MB)

---

## 📊 Current Quota Status

```
Quota              Limit   Used
Storage            512 MB  568 MB  ❌ EXCEEDED (+56 MB)
Pull Traffic       5.0 GB   38 MB  ✅ OK
```

**Account**: con-itau-industrializacao
**Registry**: br.icr.io
**Namespace**: br-ibm-images

---

## ✅ Solution 1: Delete Old/Unused Images (FASTEST)

### Current Images in Registry:

```bash
ibmcloud cr images --restrict br-ibm-images
```

**Result**:
- java-mcp-s3-git-tools:1.0.0-amd64 (181 MB) - 3 months old
- mjc-mermaid-validator:1.0.17 (68 MB) - duplicate
- mcp-arc-s3-tool:2.1.17-amd64 (347 MB) - NEW
- mjc-mermaid-validator:1.0.17-llm-ready-amd64 (68 MB) - NEW

### Recommended Deletions:

```bash
# Delete old java-mcp-s3-git-tools (181 MB) - saves 181 MB
ibmcloud cr image-rm br.icr.io/br-ibm-images/java-mcp-s3-git-tools:1.0.0-amd64

# Delete duplicate mermaid validator (68 MB) - saves 68 MB
ibmcloud cr image-rm br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17
```

**Space Freed**: 249 MB
**New Usage**: 568 - 249 = 319 MB (✅ under 512 MB limit)
**Space Available**: 512 - 319 = 193 MB

---

## ✅ Solution 2: Increase Quota

### Option A: Upgrade Plan

```bash
# Check current plan
ibmcloud cr plan

# Upgrade to paid plan (if on free plan)
ibmcloud cr plan-upgrade
```

### Option B: Increase Quota Manually

```bash
# Set higher quota (requires paid plan)
ibmcloud cr quota-set --traffic 10240 --storage 2048
```

**Reference**: https://cloud.ibm.com/docs/Registry?topic=Registry-registry_quota

---

## ✅ Solution 3: Use Different Target (Alternative)

Instead of pushing to `br.icr.io/br-ibm-images/`, use:

### Option A: AWS ECR

```bash
# Update TARGET_REGISTRY in scripts/migrate-images-parallel.sh
export TARGET_REGISTRY="<aws-account-id>.dkr.ecr.us-east-1.amazonaws.com/mjc-images"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Run migration
./scripts/migrate-images-parallel.sh
```

### Option B: JFrog Artifactory

```bash
# Configure JFrog prefix
export JFROG_PREFIX="artifactory.company.com/docker-local/"
export TARGET_REGISTRY="${JFROG_PREFIX}mjc-images"

# Run migration
./scripts/migrate-images-parallel.sh
```

---

## 🚀 Recommended Action Plan

### Step 1: Free Up Space (5 minutes)

```bash
# Login and set region
ibmcloud login
ibmcloud cr region-set br.icr.io

# Delete old images
ibmcloud cr image-rm br.icr.io/br-ibm-images/java-mcp-s3-git-tools:1.0.0-amd64
ibmcloud cr image-rm br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17

# Verify quota
ibmcloud cr quota
```

### Step 2: Re-run Migration (10-15 minutes)

```bash
# Run parallel migration
cd /Users/gregoriomomm/workspace/itau/ibm-iks-to-aws-eks-migration
./scripts/migrate-images-parallel.sh
```

### Step 3: Verify Success

```bash
# Check all images pushed
ibmcloud cr images --restrict br-ibm-images

# Should see 13 images total
```

---

## 📝 Commands Ready to Execute

Copy-paste these commands:

```bash
#!/bin/bash
# Quick cleanup and retry migration

echo "🧹 Step 1: Cleaning up old images..."
ibmcloud cr region-set br.icr.io
ibmcloud cr image-rm br.icr.io/br-ibm-images/java-mcp-s3-git-tools:1.0.0-amd64
ibmcloud cr image-rm br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17

echo "📊 Step 2: Checking quota..."
ibmcloud cr quota

echo "🚀 Step 3: Re-running migration..."
cd /Users/gregoriomomm/workspace/itau/ibm-iks-to-aws-eks-migration
./scripts/migrate-images-parallel.sh

echo "✅ Step 4: Verifying results..."
ibmcloud cr images --restrict br-ibm-images
```

Save as `scripts/cleanup-and-retry.sh` and run:

```bash
chmod +x scripts/cleanup-and-retry.sh
./scripts/cleanup-and-retry.sh
```

---

## 📞 Need Help?

**IBM Cloud Support**:
- URL: https://cloud.ibm.com/unifiedsupport/cases/form
- Topic: Container Registry
- Issue: Storage quota exceeded

**Documentation**:
- Quota: https://cloud.ibm.com/docs/Registry?topic=Registry-registry_quota
- Pricing: https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_plans

---

**Created**: 2025-10-30
**Status**: Ready to execute
