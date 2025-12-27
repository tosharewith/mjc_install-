# MMJC Image Versions

**Last Updated**: 2025-12-27
**Source**: mmjc-test namespace
**Status**: Ready for Air-Gapped Deployment

Complete list of Docker images running in mmjc-test namespace.

---

## Summary

- **Total Images**: 18 production images
- **Status**: ✅ All verified from mmjc-test namespace
- **Registry Pattern**: `icr.io/mjc-cr/<image>:<tag>` (IBM Cloud)
- **Air-Gapped Pattern**: `br.icr.io/br-ibm-images/<image>:<tag>`

---

## MMJC Custom Applications

| Component | Image | Version | Deployment |
|-----------|-------|---------|------------|
| Agents Service | `icr.io/mjc-cr/mmjc-agents` | `0.0.2` | agents-mmjc-test |
| Frontend | `icr.io/mjc-cr/mmjc-frontend` | `0.0.2` | frontend-mmjc-test |
| Process Orchestrator (PO) | `icr.io/mjc-cr/mmjc-po` | `0.0.2` | po-mmjc-test |
| Entities Manager | `icr.io/mjc-cr/mojoco-entities-manager` | `0.0.2` | em-mmjc-test |
| Mermaid Validator | `icr.io/mjc-cr/mjc-mermaid-validator` | `1.0.17-llm-ready-amd64` | mermaid-validator-api |

---

## MCP (Model Context Protocol) Servers

| Component | Image | Version | Deployment |
|-----------|-------|---------|------------|
| Git-S3 Server | `icr.io/mjc-cr/go-mcp-git-s3` | `1.0.31` | mcp-git-s3-server |
| ARC S3 Server | `icr.io/mjc-cr/arc-spring-api` | `3.1.2-amd64` | mcp-arc-s3-server |
| Context Forge (Gateway) | `icr.io/mjc-cr/mcp-context-forge` | `0.9.0` | mcp-gateway-test |
| Milvus DB Server | `icr.io/mjc-cr/mcp-milvus-db` | `0.0.2` | mcp-milvus-db-test |

---

## Infrastructure Components

### Vector Database (Milvus Cluster)

| Component | Image | Version | Type |
|-----------|-------|---------|------|
| Milvus Proxy | `milvusdb/milvus` | `v2.5.15` | Deployment |
| Milvus DataNode | `milvusdb/milvus` | `v2.5.15` | Deployment |
| Milvus IndexNode | `milvusdb/milvus` | `v2.5.15` | Deployment |
| Milvus QueryNode | `milvusdb/milvus` | `v2.5.15` | Deployment |
| Milvus MixCoord | `milvusdb/milvus` | `v2.5.15` | Deployment |
| Attu (Milvus UI) | `zilliz/attu` | `v2.5.6` | Deployment |
| etcd | `docker.io/milvusdb/etcd` | `3.5.18-r1` | StatefulSet |

### Message Queue

| Component | Image | Version | Type |
|-----------|-------|---------|------|
| Kafka | `docker.io/bitnami/kafka` | `3.1.0-debian-10-r52` | StatefulSet |
| Zookeeper | `docker.io/bitnami/zookeeper` | `3.7.0-debian-10-r320` | StatefulSet |

### Storage & Cache

| Component | Image | Version | Type |
|-----------|-------|---------|------|
| MinIO | `minio/minio` | `RELEASE.2024-05-28T17-19-04Z` | StatefulSet |
| Redis | `redis` | `8.0.2` | StatefulSet |

---

## Services Exposed

| Service | Type | Ports | Selector |
|---------|------|-------|----------|
| agents-mmjc-test | ClusterIP | 80/TCP | app=agents-mmjc |
| em-mmjc-test | ClusterIP | 80/TCP | app=em-mmjc |
| frontend-mmjc-test | ClusterIP | 80/TCP | app=frontend-mmjc |
| mcp-arc-s3-service | ClusterIP | 8383/TCP, 8443/TCP | app=mcp-arc-s3-server |
| mcp-gateway-test | ClusterIP | 80/TCP | app=mcp-gateway |
| mcp-git-s3-server | ClusterIP | 8080/TCP, 8443/TCP, 9090/TCP | app=mcp-git-s3-server |
| mcp-git-s3-server-lb | LoadBalancer | 80/TCP, 443/TCP | app=mcp-git-s3-server |
| mcp-milvus-db-test | ClusterIP | 8903/TCP | app=mcp-milvus-db |
| mermaid-validator-api | ClusterIP | 80/TCP | app=mermaid-validator-api |
| milvus-mmjc-test | ClusterIP | 19530/TCP, 9091/TCP | component=proxy |
| my-attu-svc | ClusterIP | 3000/TCP | app=attu |
| po-mmjc-test | ClusterIP | 80/TCP | app=po-mmjc |
| redis-service-test | ClusterIP | 6379/TCP | app=redis-cluster |

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

## Air-Gapped Deployment Images

For air-gapped installations, retag from `icr.io/mjc-cr/` to `br.icr.io/br-ibm-images/`:

```bash
# MMJC Applications
br.icr.io/br-ibm-images/mmjc-agents:0.0.2
br.icr.io/br-ibm-images/mmjc-frontend:0.0.2
br.icr.io/br-ibm-images/mmjc-po:0.0.2
br.icr.io/br-ibm-images/mojoco-entities-manager:0.0.2
br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64

# MCP Servers
br.icr.io/br-ibm-images/go-mcp-git-s3:1.0.31
br.icr.io/br-ibm-images/arc-spring-api:3.1.2-amd64
br.icr.io/br-ibm-images/mcp-context-forge:0.9.0
br.icr.io/br-ibm-images/mcp-milvus-db:0.0.2

# Infrastructure
br.icr.io/br-ibm-images/milvus:v2.5.15
br.icr.io/br-ibm-images/attu:v2.5.6
br.icr.io/br-ibm-images/etcd:3.5.18-r1
br.icr.io/br-ibm-images/minio:RELEASE.2024-05-28T17-19-04Z
br.icr.io/br-ibm-images/redis:8.0.2
br.icr.io/br-ibm-images/kafka:3.1.0-debian-10-r52
br.icr.io/br-ibm-images/zookeeper:3.7.0-debian-10-r320
```

---

## Known Issues

### Deprecated Image Tags

| Component | Running Version | Status |
|-----------|-----------------|--------|
| Kafka | `bitnami/kafka:3.1.0-debian-10-r52` | ⚠️ Tag no longer available on Docker Hub |
| Zookeeper | `bitnami/zookeeper:3.7.0-debian-10-r320` | ⚠️ Tag no longer available on Docker Hub |
| Zookeeper Pod | `milvus-mmjc-test-zookeeper-0` | ⚠️ ImagePullBackOff |

**Resolution Options:**
1. Export directly from cluster nodes where images are cached
2. Use newer Bitnami versions (may have breaking changes)
3. Migrate Milvus to use Pulsar instead of Kafka (recommended by Milvus)

---

## Deployment Instructions

### 1. Pull and Retag Images

```bash
./scripts/pull-and-retag-images.sh
```

### 2. Push to Artifactory

```bash
docker login br.icr.io
./scripts/pull-and-retag-images.sh --push
```

### 3. Deploy with Kustomize

```bash
# For IBM Cloud deployment
kubectl apply -k kustomize/mmjc-test

# For air-gapped deployment
kubectl apply -k kustomize/overlays/artifactory
```

---

## Notes

1. **Entities Manager**: New service (mojoco-entities-manager) added for entity management
2. **ARC Spring API**: Image renamed from `mcp-arc-s3-server` to `arc-spring-api`, version 3.1.2
4. **Context Forge**: Updated from 0.8.0 to 0.9.0
5. **PostgreSQL**: Not included (managed service - uses IBM Cloud PostgreSQL)
6. **Kafka/Zookeeper**: Tags deprecated - use cached images or migrate to Pulsar

---

## Related Documentation

- `INSTALLATION_GUIDE_COMPLETE.md` - Complete installation instructions
- `CONFIG_SYNC_STATUS.md` - Component sync verification
- `GAP_ANALYSIS_REPORT.md` - Cluster vs codebase analysis
- `scripts/pull-and-retag-images.sh` - Image migration script
- `scripts/generate-installation-configs.sh` - Config generator
