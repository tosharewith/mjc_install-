# MMJC Image Versions

**Last Updated**: 2025-11-12
**Status**: Ready for Air-Gapped Deployment

Complete list of Docker images pulled and retagged for Artifactory deployment.

---

## Summary

- **Total Images**: 15 production images
- **Status**: ✅ All successfully pulled and retagged
- **Registry Pattern**: `br.icr.io/br-ibm-images/<image>:<tag>`
- **Missing**: Kafka and Zookeeper (deprecated tags - see notes below)

---

## MMJC Custom Applications

| Component | Image | Version |
|-----------|-------|---------|
| Agents Service | `br.icr.io/br-ibm-images/mmjc-agents` | `0.0.2` |
| Frontend | `br.icr.io/br-ibm-images/mmjc-frontend` | `0.0.2` |
| Product Owner (PO) | `br.icr.io/br-ibm-images/mmjc-po` | `0.0.2` |
| Airflow Service | `br.icr.io/br-ibm-images/mmjc-airflow-service` | `latest` |
| Mermaid Validator | `br.icr.io/br-ibm-images/mjc-mermaid-validator` | `1.0.17-llm-ready-amd64` |

---

## MCP (Model Context Protocol) Servers

| Component | Image | Version |
|-----------|-------|---------|
| Git-S3 Server | `br.icr.io/br-ibm-images/go-mcp-git-s3` | `1.0.31` |
| ARC S3 Server | `br.icr.io/br-ibm-images/mcp-arc-s3-server` | `2.1.45-amd64` |
| Context Forge | `br.icr.io/br-ibm-images/mcp-context-forge` | `0.8.0` |
| Milvus DB Server | `br.icr.io/br-ibm-images/mcp-milvus-db` | `0.0.2` |

---

## Infrastructure Components

### Vector Database

| Component | Image | Version |
|-----------|-------|---------|
| Milvus | `br.icr.io/br-ibm-images/milvus` | `v2.5.15` |
| Attu (Milvus UI) | `br.icr.io/br-ibm-images/attu` | `v2.5.6` |
| etcd | `br.icr.io/br-ibm-images/etcd` | `3.5.18-r1` |

### Storage & Cache

| Component | Image | Version |
|-----------|-------|---------|
| MinIO | `br.icr.io/br-ibm-images/minio` | `RELEASE.2024-05-28T17-19-04Z` |
| Redis | `br.icr.io/br-ibm-images/redis` | `8.0.2` |

### Monitoring

| Component | Image | Version |
|-----------|-------|---------|
| StatsD Exporter | `br.icr.io/br-ibm-images/statsd-exporter` | `v0.28.0` |

---

## Missing Images (Cluster-Only)

These images are running in the current cluster but failed to pull from Docker Hub due to deprecated/removed tags:

| Component | Running Version | Status |
|-----------|-----------------|--------|
| Kafka | `bitnami/kafka:3.1.0-debian-10-r52` | ⚠️ Tag no longer available |
| Zookeeper | `bitnami/zookeeper:3.7.0-debian-10-r320` | ⚠️ Tag no longer available |

**Resolution Options:**
1. Export directly from cluster: `kubectl get pods -o yaml > kafka-zk-pods.yaml` then extract images
2. Use newer Bitnami versions (breaking changes possible)
3. Keep using cluster-cached versions (not portable to new clusters)

---

## Image Registry Mapping

### Source (IBM Cloud Container Registry)
```
icr.io/mjc-cr/<image>:<version>
```

### Target (Artifactory for Air-Gapped)
```
br.icr.io/br-ibm-images/<image>:<version>
```

---

## Version Changes from Previous Deployment

| Image | Previous | Current | Change |
|-------|----------|---------|--------|
| mmjc-airflow-service | `3.0.2` | `latest` | Updated to match cluster |
| mcp-arc-s3-server | `2.1.17-amd64` | `2.1.45-amd64` | ⬆️ Version bump |

---

## Deployment Instructions

### 1. View Tagged Images Locally

```bash
export DOCKER_HOST="unix:///Users/gregoriomomm/.colima/default/docker.sock"
docker images br.icr.io/br-ibm-images/
```

### 2. Push to Artifactory

```bash
# Login to Artifactory
docker login br.icr.io

# Push all images
./scripts/pull-and-retag-images.sh --push
```

### 3. Deploy with Kustomize

```bash
# For air-gapped deployment
kubectl apply -k kustomize/overlays/artifactory

# For IBM Cloud deployment
kubectl apply -k kustomize/mmjc-test
kubectl apply -k kustomize/airflow-test
```

---

## Installation-Specific Configuration

All images are now available with both registry patterns:

**IBM Cloud (ICR):**
- Use `icr.io/mjc-cr/*` in `kustomize/mmjc-test/`
- Use `icr.io/mjc-cr/*` in `kustomize/airflow-test/`

**Air-Gapped (Artifactory):**
- Use `br.icr.io/br-ibm-images/*` in `kustomize/overlays/artifactory/`

Configuration generator creates installation-specific overlays:
```bash
./scripts/generate-installation-configs.sh <values-file> <output-dir>
```

---

## Notes

1. **Airflow Version**: Changed from `3.0.2` to `latest` to match running cluster
2. **Kafka/Zookeeper**: Tags `3.1.0-debian-10-r52` and `3.7.0-debian-10-r320` no longer exist on Docker Hub
3. **MCP Arc Server**: Two versions tagged (`2.1.17` and `2.1.45`) - use `2.1.45-amd64` for new deployments
4. **PostgreSQL**: Not included (managed service - uses IBM Cloud PostgreSQL 16.8)
5. **Image Sizes**: Total ~6.5GB for all images

---

## Verification

Check all images are present:
```bash
# Count should be 15
docker images br.icr.io/br-ibm-images/ | grep -v REPOSITORY | wc -l

# List with sizes
docker images br.icr.io/br-ibm-images/ --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

---

## Related Documentation

- `INSTALLATION_GUIDE_COMPLETE.md` - Complete installation instructions
- `CONFIG_SYNC_STATUS.md` - Component sync verification
- `GAP_ANALYSIS_REPORT.md` - Cluster vs codebase analysis
- `scripts/pull-and-retag-images.sh` - Image migration script
- `scripts/generate-installation-configs.sh` - Config generator
