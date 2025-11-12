# Gap Analysis & Configuration Update Report

**Date**: 2025-11-02
**Cluster**: IBM Cloud (mjc-cluster)
**Analysis By**: Automated Gap Analysis Tool

---

## Executive Summary

This report documents the gap analysis between the IBM Cloud Kubernetes cluster and the local codebase for the `mmjc-test` and `airflow-test` namespaces. All identified gaps have been addressed and configurations updated to match the current production state.

### Key Findings

- ✅ **7 missing image definitions** added to `mmjc-test` kustomization
- ✅ **1 image version mismatch** corrected (mcp-context-forge: 0.6.0 → 0.8.0)
- ✅ **25 secret templates** extracted from `mmjc-test` namespace
- ✅ **9 secret templates** documented for `airflow-test` namespace
- ✅ **Airflow version pinned** from `latest` to `3.0.2`
- ⚠️ **Database connection scheme** needs manual fix (`postgres://` → `postgresql://`)

---

## 1. MMJC-TEST Namespace

### 1.1 Image Version Comparison

| Component | Cluster | Kustomize (Before) | Kustomize (After) | Status |
|-----------|---------|-------------------|-------------------|---------|
| mmjc-agents | 0.0.2 | 0.0.2 | 0.0.2 | ✅ Match |
| mmjc-frontend | 0.0.2 | 0.0.2 | 0.0.2 | ✅ Match |
| mmjc-po | 0.0.2 | 0.0.2 | 0.0.2 | ✅ Match |
| go-mcp-git-s3 | 1.0.31 | 1.0.31 | 1.0.31 | ✅ Match |
| mcp-milvus-db | 0.0.2 | 0.0.2 | 0.0.2 | ✅ Match |
| mjc-mermaid-validator | 1.0.17-llm-ready-amd64 | 1.0.17-llm-ready-amd64 | 1.0.17-llm-ready-amd64 | ✅ Match |
| **mcp-context-forge** | icr.io/mjc-cr:0.8.0 | ghcr.io/ibm:0.6.0 | **icr.io/mjc-cr:0.8.0** | ✅ **FIXED** |
| milvusdb/milvus | v2.5.15 | v2.5.15 | v2.5.15 | ✅ Match |
| zilliz/attu | v2.5.6 | v2.5.6 | v2.5.6 | ✅ Match |
| **mcp-arc-s3-server** | 2.1.45-amd64 | ❌ Missing | **2.1.45-amd64** | ✅ **ADDED** |
| **redis** | 8.0.2 | ❌ Missing | **8.0.2** | ✅ **ADDED** |
| **milvusdb/etcd** | 3.5.18-r1 | ❌ Missing | **3.5.18-r1** | ✅ **ADDED** |
| **bitnami/kafka** | 3.1.0-debian-10-r52 | ❌ Missing | **3.1.0-debian-10-r52** | ✅ **ADDED** |
| **minio/minio** | RELEASE.2024-05-28T17-19-04Z | ❌ Missing | **RELEASE.2024-05-28T17-19-04Z** | ✅ **ADDED** |
| **bitnami/zookeeper** | 3.7.0-debian-10-r320 | ❌ Missing | **3.7.0-debian-10-r320** | ✅ **ADDED** |

### 1.2 Files Updated

#### `kustomize/mmjc-test/kustomization.yaml`
```yaml
# Added missing image definitions:
images:
  - name: icr.io/mjc-cr/mcp-context-forge      # Changed from ghcr.io/ibm
    newName: icr.io/mjc-cr/mcp-context-forge
    newTag: 0.8.0                              # Updated from 0.6.0

  - name: icr.io/mjc-cr/mcp-arc-s3-server      # NEW
    newName: icr.io/mjc-cr/mcp-arc-s3-server
    newTag: 2.1.45-amd64

  - name: redis                                # NEW
    newName: redis
    newTag: "8.0.2"

  # Milvus dependencies - ALL NEW
  - name: docker.io/milvusdb/etcd
    newName: docker.io/milvusdb/etcd
    newTag: 3.5.18-r1

  - name: docker.io/bitnami/kafka
    newName: docker.io/bitnami/kafka
    newTag: 3.1.0-debian-10-r52

  - name: minio/minio
    newName: minio/minio
    newTag: RELEASE.2024-05-28T17-19-04Z

  - name: docker.io/bitnami/zookeeper
    newName: docker.io/bitnami/zookeeper
    newTag: 3.7.0-debian-10-r320
```

#### `kustomize/overlays/artifactory/kustomization.yaml`
Updated to include all new images with `br.icr.io/br-ibm-images` prefix for air-gapped deployments.

#### `kustomize/mmjc-test/secrets/`
- ✅ `secrets-template.json` - Template for all 25 secrets
- ✅ `secrets-keys.json` - Reference list of secret keys

### 1.3 Secrets Inventory

**Total Secrets**: 25 (excluding service account tokens)

Key secrets:
- `all-icr-io-mmjc` - Docker registry credentials
- `postgresql-secret-test` - PostgreSQL database credentials
- `mcp-gateway-*` - MCP Gateway authentication
- `azure-openai-*` - Azure OpenAI API configuration
- `github-app-secrets` - GitHub App credentials
- `milvus-mmjc-test-minio` - Minio object storage
- `s3-*-tools` - S3 access credentials

---

## 2. AIRFLOW-TEST Namespace

### 2.1 Image Version Comparison

| Component | Cluster | Kustomize (Before) | Kustomize (After) | Status |
|-----------|---------|-------------------|-------------------|---------|
| **mmjc-airflow-service** | 3.0.2 | **latest** | **3.0.2** | ✅ **FIXED** |
| statsd-exporter | v0.28.0 | v0.28.0 | v0.28.0 | ✅ Match |

### 2.2 Files Updated

#### `kustomize/airflow-test/kustomization.yaml`
```yaml
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: icr.io/mjc-cr/mmjc-airflow-service
    newTag: "3.0.2"  # Changed from 'latest' to pin specific version
```

**Benefits**:
- Predictable deployments
- Easier rollback capability
- Consistent with cluster state
- No surprise version changes

#### `kustomize/airflow-test/secrets/README.md`
Created comprehensive documentation for all required secrets.

### 2.3 Critical Issue Identified

⚠️ **Database Connection Scheme** (Requires Manual Fix)

**Current**: `postgres://user:pass@host/db`
**Required**: `postgresql://user:pass@host/db`

**Why**: SQLAlchemy 1.4+ (used by Airflow 3.x) deprecated `postgres://` scheme. Currently working due to Airflow compatibility shim, but will break in future versions.

**Testing Completed**:
- ✅ Tested `postgres://` scheme: Works with warnings
- ✅ Tested `postgresql://` scheme: Works perfectly
- ✅ Confirmed cluster currently using `postgres://` (needs fix)

**Fix Command**:
```bash
# Get current connection string
current=$(kubectl get secret -n airflow-test airflow-postgres-connection-test \
  -o jsonpath='{.data.connection}' | base64 -d)

# Fix scheme
fixed=$(echo "$current" | sed 's|^postgres://|postgresql://|')

# Update secret
echo -n "$fixed" | base64 | kubectl patch secret airflow-postgres-connection-test \
  -n airflow-test --type='json' \
  -p='[{"op": "replace", "path": "/data/connection", "value": "'$(echo -n "$fixed" | base64)'"}]'

# Restart deployments to pick up new connection
kubectl rollout restart deployment -n airflow-test
kubectl rollout restart statefulset -n airflow-test
```

### 2.4 Secrets Inventory

**Total Secrets**: 9 (excluding Helm releases and service account tokens)

Required secrets:
- `airflow-postgres-connection-test` - Database connection string ⚠️ **Needs scheme fix**
- `airflow-postgres-cert-test` - PostgreSQL SSL certificate
- `airflow-redis-connection-test` - Redis broker for Celery
- `airflow-test-fernet-key` - Encryption key
- `airflow-test-jwt-secret` - API authentication
- `airflow-test-webserver-secret-key` - Flask secret
- `all-icr-io-mmjc` - Docker registry credentials
- `cos-mmjc-airflow-secret` - Cloud Object Storage (for remote logs)
- `mmjc-cos-test-secrets` - Additional COS credentials

---

## 3. Image Registry References

### 3.1 br.icr.io References

**Total References Found**: 321

**Locations**:
- `config/registry-mapping.yaml` - Air-gapped deployment configuration
- `kustomize/overlays/artifactory/kustomization.yaml` - Artifactory overlay (updated)
- `helm/airflow-values-aws-eks.yaml` - Helm values for AWS
- `helm/milvus-values-aws-eks.yaml` - Helm values for AWS (commented)

**Status**: ✅ All references are in overlay configurations for air-gapped deployments. Base kustomizations use `icr.io/mjc-cr/*` correctly.

**Note**: The `br.icr.io` registry is for Artifactory-based air-gapped deployments. The overlay system properly handles this transformation.

---

## 4. PostgreSQL Compatibility

### 4.1 Version Support

**Your PostgreSQL Version**: 16.8
**Airflow 3.0.2 Support**: PostgreSQL 13, 14, 15, 16, 17

✅ **PostgreSQL 16.8 is fully supported** (16.8 is a patch release within the supported major version 16)

### 4.2 Connection Scheme Requirement

- **SQLAlchemy 1.4+**: Requires `postgresql://` (not `postgres://`)
- **Airflow 2.3+**: Adopted SQLAlchemy 1.4
- **Airflow 3.0+**: Requires SQLAlchemy 1.4+
- **Current Cluster**: Using `postgres://` with compatibility shim (temporary)
- **Action Required**: Update to `postgresql://` before next Airflow upgrade

---

## 5. Deployment Resources

### 5.1 MMJC-TEST Workloads

**Deployments** (13):
- agents-mmjc-test (4 replicas)
- frontend-mmjc-test (1 replica)
- mcp-gateway-test (1 replica)
- mcp-git-s3-server (1 replica)
- mcp-milvus-db-test (1 replica)
- mermaid-validator-api (2 replicas)
- milvus-mmjc-test-datanode (2 replicas)
- milvus-mmjc-test-indexnode (2 replicas)
- milvus-mmjc-test-mixcoord (1 replica)
- milvus-mmjc-test-proxy (1 replica)
- milvus-mmjc-test-querynode (3 replicas)
- my-attu (1 replica)
- po-mmjc-test (1 replica)

**StatefulSets** (6):
- mcp-arc-s3-server (1 replica)
- milvus-mmjc-test-etcd (3 replicas)
- milvus-mmjc-test-kafka (3 replicas)
- milvus-mmjc-test-minio (4 replicas)
- milvus-mmjc-test-zookeeper (3 replicas)
- redis-cluster-test (1 replica)

**Total Pods**: 35
**Total Resources**: 220 (including services, configmaps, PVCs, etc.)

### 5.2 AIRFLOW-TEST Workloads

**Deployments** (4):
- airflow-test-api-server (1 replica)
- airflow-test-dag-processor (1 replica)
- airflow-test-scheduler (1 replica)
- airflow-test-statsd (1 replica)

**StatefulSets** (2):
- airflow-test-triggerer (1 replica)
- airflow-test-worker (1 replica)

**Total Pods**: 6

---

## 6. Action Items

### Immediate Actions Required

1. ⚠️ **HIGH PRIORITY**: Fix database connection scheme in `airflow-test`
   - Secret: `airflow-postgres-connection-test`
   - Change: `postgres://` → `postgresql://`
   - Impact: Prevents future compatibility issues
   - See Section 2.3 for exact commands

### Recommended Actions

2. 📋 **Update secret templates with actual values**
   - Location: `kustomize/mmjc-test/secrets/secrets-template.json`
   - Location: `kustomize/airflow-test/secrets/airflow-test-secrets-template.yaml`
   - Replace `PLACEHOLDER_BASE64_VALUE_HERE` with actual base64-encoded values

3. 🧪 **Test kustomize build**
   ```bash
   # Test mmjc-test
   kubectl kustomize kustomize/mmjc-test > /tmp/mmjc-test-rendered.yaml

   # Test airflow-test
   kubectl kustomize kustomize/airflow-test > /tmp/airflow-test-rendered.yaml

   # Test artifactory overlay
   kubectl kustomize kustomize/overlays/artifactory > /tmp/artifactory-rendered.yaml
   ```

4. 🔄 **Deploy updated configurations** (when ready)
   ```bash
   # Deploy to cluster (dry-run first)
   kubectl apply -k kustomize/mmjc-test --dry-run=client
   kubectl apply -k kustomize/airflow-test --dry-run=client
   ```

---

## 7. Files Changed Summary

### Modified Files

1. `kustomize/mmjc-test/kustomization.yaml`
   - Added 7 missing image definitions
   - Fixed mcp-context-forge registry and version

2. `kustomize/overlays/artifactory/kustomization.yaml`
   - Updated to include all new images for air-gapped deployment

3. `kustomize/airflow-test/kustomization.yaml`
   - Pinned Airflow version from `latest` to `3.0.2`

### New Files

4. `kustomize/mmjc-test/secrets/secrets-template.json`
   - Template for 25 secrets from cluster

5. `kustomize/mmjc-test/secrets/secrets-keys.json`
   - Reference list of secret keys

6. `kustomize/airflow-test/secrets/README.md`
   - Documentation for Airflow secrets

7. `GAP_ANALYSIS_REPORT.md` (this file)
   - Comprehensive analysis and recommendations

---

## 8. Verification Checklist

Before deploying updated configurations:

- [ ] Reviewed all image version changes
- [ ] Verified secret templates are complete
- [ ] Fixed database connection scheme to `postgresql://`
- [ ] Tested kustomize build for both namespaces
- [ ] Reviewed generated YAML for correctness
- [ ] Backed up current cluster secrets
- [ ] Planned maintenance window for Airflow restart (if fixing DB connection)
- [ ] Documented rollback procedure
- [ ] Notified relevant teams

---

## 9. Next Steps

### For AWS Migration

When migrating to AWS, consider:

1. **Image Registry**: Decide between:
   - Continue using IBM Cloud Container Registry (`icr.io/mjc-cr`)
   - Migrate to AWS ECR
   - Use Artifactory overlay (`br.icr.io`) for air-gapped

2. **Database Migration**:
   - Ensure PostgreSQL connection uses `postgresql://` scheme
   - Plan for database migration/replication
   - Update connection strings in secrets

3. **Object Storage**:
   - Migrate from IBM Cloud Object Storage to AWS S3
   - Update Airflow remote logging configuration
   - Update Minio/MinIO configurations

4. **Networking**:
   - Review ingress configurations
   - Update DNS entries
   - Configure AWS load balancers

---

## Appendix A: Cluster State Export

All cluster state has been exported to:
- `/tmp/cluster-state-analysis/mmjc-test/`
- `/tmp/secrets-export/mmjc-test/`
- `/tmp/secrets-export/airflow-test/`

Files available for review:
- `deployments.yaml` - All deployment manifests
- `statefulsets.yaml` - All statefulset manifests
- `configmaps.yaml` - All configmap manifests
- `secrets-template.json` - Secret structures (no values)
- `secrets-keys.json` - Secret key references

---

**Report Generated**: 2025-11-02
**Analysis Tool**: Claude Code Gap Analysis
**Cluster**: mjc-cluster (IBM Cloud)
**Namespaces Analyzed**: mmjc-test, airflow-test
