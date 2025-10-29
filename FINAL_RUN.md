# 🚀 FINAL - Run Migration Now

**Status**: ✅ ALL READY
**Account**: iseaitools (logged in)
**Source**: `us.icr.io/mmjc-cr/` (US region)
**Target**: `br.icr.io/br-ibm-images/` (Brazil region)
**Access**: ✅ Verified

---

## 📦 Images to Migrate (7 images from ACTUAL deployments)

**Source**: `icr.io/mjc-cr` (GLOBAL region)
**Target**: `br.icr.io/br-ibm-images/` (Brazil region)

| # | Image | Source | Used In |
|---|-------|--------|---------|
| 1 | mmjc-airflow-service:latest | icr.io/mjc-cr | airflow-test |
| 2 | mcp-arc-s3-tool:2.1.17-amd64 | icr.io/mjc-cr | milvus-mmjc-dev |
| 3 | mcp-milvus-db:0.0.1 | icr.io/mjc-cr | milvus-mmjc-dev |
| 4 | mjc-mermaid-validator:1.0.17-llm-ready-amd64 | icr.io/mjc-cr | milvus-mmjc-dev |
| 5 | mmjc-po:0.0.1 | icr.io/mjc-cr | milvus-mmjc-dev |
| 6 | understanding-agent-arc:1.5.5 | icr.io/mjc-cr | milvus-mmjc-dev |
| 7 | understanding-agent-arc:v1.6.57 | icr.io/mjc-cr | milvus-mmjc-dev |

**Total**: ~1GB (download + upload)
**Time**: ~15-20 minutes

---

## ⚡ RUN NOW (3 Commands)

```bash
# 1. Setup Docker
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh

# 2. Migrate ALL 7 images
./scripts/migrate-images-manual.sh

# 3. Update Kubernetes manifests
./scripts/update-image-refs.sh
```

---

## 📋 What Changed

### Previous (WRONG) Migration:
- Source: `us.icr.io/mmjc-cr` (US region namespace)
- Images: java-mcp-s3-git-tools, mmjc-agents-server, mmjc-bff-v2, mmjc-frontend-v2, mmjc-tools
- **Problem**: NONE of these are used in deployments

### Corrected Migration:
- Source: `icr.io/mjc-cr` (GLOBAL region namespace)
- Images: All 7 from actual airflow-test and milvus-mmjc-dev deployments
- **Verified**: All images exist and are actually used

---

## 📊 What Happens

### Step 2 Output:

```
[6/7] Migrating images...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: icr.io/mjc-cr/mmjc-airflow-service:latest
   → Target: br.icr.io/br-ibm-images/mmjc-airflow-service:latest
   [1/3] Pulling source image...
   [2/3] Tagging image...
   [3/3] Pushing to target registry...
   ✅ Push successful

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Migrating: icr.io/mjc-cr/mcp-arc-s3-tool:2.1.17-amd64
   → Target: br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64
   [1/3] Pulling source image...
   [2/3] Tagging image...
   [3/3] Pushing to target registry...
   ✅ Push successful

... (repeats for remaining 5 images) ...

📊 Migration Summary
✅ Successfully migrated: 7
🎉 Migration completed successfully!
```

---

## ✅ After Migration

### Verify:

```bash
# Check all images in Brazil registry
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images

# Expected output (8 images total):
# br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17 (existing)
# br.icr.io/br-ibm-images/mmjc-airflow-service:latest (NEW)
# br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64 (NEW)
# br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1 (NEW)
# br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64 (NEW)
# br.icr.io/br-ibm-images/mmjc-po:0.0.1 (NEW)
# br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5 (NEW)
# br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57 (NEW)
```

### Test Pull:

```bash
# Test pulling one image
docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest
```

---

## 🧹 Cleanup After Migration

```bash
# Free up local disk space (optional)
docker system prune -a

# This removes all local copies
# Wait until you've verified deployment!
```

---

## 📋 Notes

### These are ALL your custom images:
- ✅ You built them → You can migrate them
- ✅ No licensing issues
- ✅ Safe to redistribute in your own registry

### Public images (NOT being migrated):
- Milvus, Kafka, Zookeeper, Etcd - stay in docker.io
- StatsD Exporter - stays in quay.io
- These will be pulled from public registries (no licensing issues)

---

## 🎯 Ready to Go?

Just run the 3 commands:

```bash
cd ~/workspace/itau/ibm-iks-to-aws-eks-migration
source ./scripts/setup-docker-colima.sh
./scripts/migrate-images-manual.sh
```

**Time**: 15-20 minutes
**Network**: ~1GB download + ~1GB upload
**Disk**: Need ~2-3GB free space

---

**Go!** 🚀
