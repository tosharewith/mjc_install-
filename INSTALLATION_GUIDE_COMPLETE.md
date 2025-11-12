# MMJC Installation Guide

**Version**: 1.0
**Last Updated**: 2025-11-02

Complete guide for deploying MMJC to any environment.

---

## Quick Reference

| Document | Purpose |
|----------|---------|
| This guide | Complete installation instructions |
| `CONFIG_SYNC_STATUS.md` | Component sync verification, image manifest |
| `IMMEDIATE_FIX_CHECKPOINTS_ERROR.md` | Fix agents database error |
| `SYNC_PLAN_IBM_TO_AWS.md` | AWS migration plan |
| `GAP_ANALYSIS_REPORT.md` | Cluster state analysis |
| `scripts/pull-and-retag-images.sh` | Image migration for air-gapped |
| `scripts/generate-installation-configs.sh` | Generate configs from template |

---

## Installation Steps

### 1. Pull and Retag Images (for Air-Gapped)

```bash
# Login to Artifactory
docker login br.icr.io

# Pull all images from ICR and retag for Artifactory
./scripts/pull-and-retag-images.sh --push

# Verify (17 images total)
docker images br.icr.io/br-ibm-images/*
```

### 2. Configure Installation

```bash
# Copy template
cp kustomize/base/common-config/installation-values-template.yaml my-install.yaml

# Edit with your values
vi my-install.yaml

# Generate configs
./scripts/generate-installation-configs.sh my-install.yaml ./output
```

### 3. Setup Database

```bash
# Initialize PostgreSQL (creates checkpoints table)
kubectl apply -f kustomize/mmjc-test/jobs/init-database.yaml
kubectl wait --for=condition=complete job/init-mmjc-database -n mmjc-test
```

### 4. Deploy

```bash
# Apply secrets (after filling values)
kubectl apply -f ./output/secrets-template.yaml

# Deploy with kustomize
kubectl apply -k ./output/overlay
```

---

## Image Registry Patterns

**ICR** (IBM Cloud):
```
icr.io/mjc-cr/<image-name>:<version>
```

**Artifactory** (Air-Gapped):
```
br.icr.io/br-ibm-images/<image-name>:<version>
```

All MCP components (git-s3, arc-s3, milvus-db, context-forge) are **SYNCED** ✅

---

## Installation-Specific Values

Template all these per installation:
- Database host/port (PostgreSQL 16.x)
- S3 endpoint and buckets
- LLM gateway URL
- MCP gateway server ID
- Git credentials
- Image registry
- Kubernetes namespaces

See `kustomize/base/common-config/installation-values-template.yaml`

---

**For detailed instructions, see full docs above.**
