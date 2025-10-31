# 🔍 Image Migration Analysis - COMPLETE

**Date**: 2025-10-29
**Status**: ⚠️ CRITICAL - Current migration is migrating WRONG images

---

## 🚨 Critical Finding

### Currently Running Migration (WRONG):
- **Source**: `us.icr.io/mmjc-cr/` (US region namespace)
- **Status**: Background process b13414 - Image 2/7 in progress
- **Problem**: These images are NOT used in actual deployments

### Actually Needed Images:
- **Source**: `icr.io/mjc-cr/` (GLOBAL region namespace)
- **Used in**: airflow-test, milvus-mmjc-test deployments
- **Status**: NOT being migrated

---

## 📦 Image Comparison

### Images Being Migrated NOW (WRONG LIST):

| Image | Source | Status | Used in Deployments? |
|-------|--------|--------|---------------------|
| java-mcp-s3-git-tools:1.0.0-amd64 | us.icr.io/mmjc-cr | ✅ Migrating | ❌ NOT FOUND |
| mmjc-agents-server:19-main-... | us.icr.io/mmjc-cr | 🔄 In progress | ❌ NOT FOUND |
| mmjc-bff-v2:0.0.1 | us.icr.io/mmjc-cr | ⏳ Queued | ❌ NOT FOUND |
| mmjc-bff-v2:0.0.2 | us.icr.io/mmjc-cr | ⏳ Queued | ❌ NOT FOUND |
| mmjc-frontend-v2:0.0.1 | us.icr.io/mmjc-cr | ⏳ Queued | ❌ NOT FOUND |
| mmjc-frontend-v2:0.0.2 | us.icr.io/mmjc-cr | ⏳ Queued | ❌ NOT FOUND |
| mmjc-tools:1.0.1-fixed | us.icr.io/mmjc-cr | ⏳ Queued | ❌ NOT FOUND |

**Total**: 7 images (~1GB) - NONE are used in deployments

---

### Images ACTUALLY Used in Deployments (CORRECT LIST):

#### From airflow-test/airflow-test-complete.yaml:

| Image | Source | Status | Used Where |
|-------|--------|--------|------------|
| mmjc-airflow-service:latest | icr.io/mjc-cr | ❌ NOT migrating | Airflow scheduler, webserver, worker, triggerer |

#### From milvus-mmjc-test/milvus-complete.yaml:

| Image | Source | Status | Used Where |
|-------|--------|--------|------------|
| mcp-arc-s3-tool:2.1.17-amd64 | icr.io/mjc-cr | ❌ NOT migrating | MCP Arc S3 Service |
| mcp-milvus-db:0.0.1 | icr.io/mjc-cr | ❌ NOT migrating | MCP Milvus Service |
| mjc-mermaid-validator:1.0.17-llm-ready-amd64 | icr.io/mjc-cr | ❌ NOT migrating | Mermaid Validator |
| mmjc-po:0.0.1 | icr.io/mjc-cr | ❌ NOT migrating | MMJC PO Service |
| understanding-agent-arc:1.5.5 | icr.io/mjc-cr | ❌ NOT migrating | Understanding Agent Init |
| understanding-agent-arc:v1.6.57 | icr.io/mjc-cr | ❌ NOT migrating | Understanding Agent (2 instances) |

**Total**: 7 images (6 unique + 1 with 2 versions) - ALL are actually used

---

## 🎯 Registry Analysis

### Two Separate Namespaces Found:

#### 1. us.icr.io/mmjc-cr (US Region)
- **Images found**: 7 images
- **Usage**: NONE in deployments
- **Migration status**: Currently being migrated (WRONG)

#### 2. icr.io/mjc-cr (Global Region)
- **Images found**: Hundreds of images
- **Usage**: ALL deployment images come from here
- **Migration status**: NOT being migrated (should be!)

---

## 🔧 What Needs to Happen

### Option 1: Let Current Migration Finish, Then Run Correct Migration

```bash
# 1. Let current migration complete (~15 min remaining)
# Monitor: BashOutput b13414

# 2. Run NEW migration with correct images
vim scripts/migrate-images-manual.sh
# Change SOURCE from: us.icr.io/mmjc-cr
# To: icr.io/mjc-cr

# 3. Update IMAGES array with correct list (see below)

# 4. Run migration again
./scripts/migrate-images-manual.sh
```

**Pros**:
- Current work not wasted
- May have those images for other purposes

**Cons**:
- Takes longer (another ~15 min)
- Migrates unused images

---

### Option 2: Stop Current Migration, Run Correct One

```bash
# 1. Kill current migration
# Get PID from: ps aux | grep migrate-images-manual
kill <PID>

# 2. Update script with correct source and images
vim scripts/migrate-images-manual.sh

# 3. Run corrected migration
./scripts/migrate-images-manual.sh
```

**Pros**:
- Only migrates needed images
- Saves time and bandwidth

**Cons**:
- Loses progress on current migration

---

## 📝 Correct Migration Configuration

### Source Registry:
```bash
SOURCE_REGISTRY=icr.io/mjc-cr  # NOT us.icr.io/mmjc-cr
```

### Target Registry:
```bash
TARGET_REGISTRY=br.icr.io/br-ibm-images  # This is correct
```

### Correct IMAGES Array:

```bash
IMAGES=(
    # Airflow deployment
    "icr.io/mjc-cr/mmjc-airflow-service:latest|mmjc-airflow-service|latest"

    # Milvus deployment - MCP services
    "icr.io/mjc-cr/mcp-arc-s3-tool:2.1.17-amd64|mcp-arc-s3-tool|2.1.17-amd64"
    "icr.io/mjc-cr/mcp-milvus-db:0.0.1|mcp-milvus-db|0.0.1"

    # Milvus deployment - Validators
    "icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64|mjc-mermaid-validator|1.0.17-llm-ready-amd64"

    # Milvus deployment - MMJC services
    "icr.io/mjc-cr/mmjc-po:0.0.1|mmjc-po|0.0.1"

    # Milvus deployment - Understanding Agent (both versions)
    "icr.io/mjc-cr/understanding-agent-arc:1.5.5|understanding-agent-arc|1.5.5"
    "icr.io/mjc-cr/understanding-agent-arc:v1.6.57|understanding-agent-arc|v1.6.57"
)
```

**Total**: 7 images to migrate (same count, but CORRECT ones)

---

## 📊 Deployment Usage Matrix

### airflow-test namespace:

| Deployment | Image |
|------------|-------|
| airflow-scheduler | mmjc-airflow-service:latest |
| airflow-webserver | mmjc-airflow-service:latest |
| airflow-worker | mmjc-airflow-service:latest |
| airflow-triggerer | mmjc-airflow-service:latest |
| git-sync (init) | mmjc-airflow-service:latest |

**Required**: 1 unique image

---

### milvus-mmjc-test namespace:

| Service | Image |
|---------|-------|
| MCP Arc S3 | mcp-arc-s3-tool:2.1.17-amd64 |
| MCP Milvus | mcp-milvus-db:0.0.1 |
| Mermaid Validator | mjc-mermaid-validator:1.0.17-llm-ready-amd64 |
| MMJC PO | mmjc-po:0.0.1 |
| Understanding Agent (init) | understanding-agent-arc:1.5.5 |
| Understanding Agent (main) | understanding-agent-arc:v1.6.57 |

**Required**: 6 images (5 unique services + 1 with version difference)

---

## 🔄 Migration Steps (Corrected)

### 1. Update Migration Script

```bash
vim scripts/migrate-images-manual.sh
```

Change line ~20:
```bash
# FROM:
SOURCE_REGISTRY="${SOURCE_REGISTRY:-us.icr.io/mmjc-cr}"

# TO:
SOURCE_REGISTRY="${SOURCE_REGISTRY:-icr.io/mjc-cr}"
```

Replace IMAGES array (around line 95):
```bash
IMAGES=(
    "icr.io/mjc-cr/mmjc-airflow-service:latest|mmjc-airflow-service|latest"
    "icr.io/mjc-cr/mcp-arc-s3-tool:2.1.17-amd64|mcp-arc-s3-tool|2.1.17-amd64"
    "icr.io/mjc-cr/mcp-milvus-db:0.0.1|mcp-milvus-db|0.0.1"
    "icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64|mjc-mermaid-validator|1.0.17-llm-ready-amd64"
    "icr.io/mjc-cr/mmjc-po:0.0.1|mmjc-po|0.0.1"
    "icr.io/mjc-cr/understanding-agent-arc:1.5.5|understanding-agent-arc|1.5.5"
    "icr.io/mjc-cr/understanding-agent-arc:v1.6.57|understanding-agent-arc|v1.6.57"
)
```

### 2. Update Image References Script

```bash
vim scripts/update-image-refs.sh
```

Update the image search/replace to match:
- `icr.io/mjc-cr` → `br.icr.io/br-ibm-images`

### 3. Run Corrected Migration

```bash
./scripts/migrate-images-manual.sh
```

---

## ✅ Verification After Correct Migration

### Check Brazil registry:

```bash
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images
```

**Expected output** (8 images total):

```
br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17 (existing)
br.icr.io/br-ibm-images/mmjc-airflow-service:latest (NEW)
br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64 (NEW)
br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1 (NEW)
br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64 (NEW)
br.icr.io/br-ibm-images/mmjc-po:0.0.1 (NEW)
br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5 (NEW)
br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57 (NEW)
```

---

## 🎯 Summary

### What Went Wrong:
- Migration script configured with `us.icr.io/mmjc-cr` namespace
- Actual deployments use `icr.io/mjc-cr` namespace
- Different namespaces = different images
- None of the images being migrated are actually used

### What's Correct:
- ✅ Target registry: `br.icr.io/br-ibm-images`
- ✅ JFrog prefix support
- ✅ Public images excluded
- ✅ Migration workflow

### What Needs Fixing:
- ❌ Source registry: `us.icr.io/mmjc-cr` → should be `icr.io/mjc-cr`
- ❌ Image list: 7 wrong images → should be 7 correct images

---

## 📋 Recommendation

**Decision needed**:

1. **Stop current migration** and run correct one (saves time)
2. **Let current finish** then run correct one (preserves work)

Either way, the corrected migration MUST be run with:
- Source: `icr.io/mjc-cr`
- Images: The 7 listed in "Correct IMAGES Array" above

---

**Next Step**: User decides which option to take.
