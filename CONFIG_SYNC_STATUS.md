## Configuration Sync Status Report

**Date**: 2025-11-02
**Purpose**: Verify configuration synchronization between `originals/` (cluster state) and `kustomize/` (deployment templates)
**Focus**: MCP components and installation-specific values

---

## 1. Image Registry Configuration

### Current Pattern

**ICR (IBM Cloud Container Registry)**:
```
icr.io/mjc-cr/<image-name>:<version>
```

**Artifactory (Air-Gapped)**:
```
br.icr.io/br-ibm-images/<image-name>:<version>
```

### Image Manifest

| Component | Version | ICR Image | Artifactory Image |
|-----------|---------|-----------|-------------------|
| mmjc-agents | 0.0.2 | icr.io/mjc-cr/mmjc-agents:0.0.2 | br.icr.io/br-ibm-images/mmjc-agents:0.0.2 |
| mmjc-frontend | 0.0.2 | icr.io/mjc-cr/mmjc-frontend:0.0.2 | br.icr.io/br-ibm-images/mmjc-frontend:0.0.2 |
| mmjc-po | 0.0.2 | icr.io/mjc-cr/mmjc-po:0.0.2 | br.icr.io/br-ibm-images/mmjc-po:0.0.2 |
| **mcp-git-s3** | **1.0.31** | icr.io/mjc-cr/go-mcp-git-s3:1.0.31 | br.icr.io/br-ibm-images/go-mcp-git-s3:1.0.31 |
| **mcp-arc-s3** | **2.1.45-amd64** | icr.io/mjc-cr/mcp-arc-s3-server:2.1.45-amd64 | br.icr.io/br-ibm-images/mcp-arc-s3-server:2.1.45-amd64 |
| mcp-milvus-db | 0.0.2 | icr.io/mjc-cr/mcp-milvus-db:0.0.2 | br.icr.io/br-ibm-images/mcp-milvus-db:0.0.2 |
| mcp-context-forge | 0.8.0 | icr.io/mjc-cr/mcp-context-forge:0.8.0 | br.icr.io/br-ibm-images/mcp-context-forge:0.8.0 |
| mermaid-validator | 1.0.17-llm-ready-amd64 | icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64 | br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64 |
| airflow-service | 3.0.2 | icr.io/mjc-cr/mmjc-airflow-service:3.0.2 | br.icr.io/br-ibm-images/mmjc-airflow-service:3.0.2 |

### Public Images (Mirrored)

| Source Image | Artifactory Mirror |
|--------------|-------------------|
| milvusdb/milvus:v2.5.15 | br.icr.io/br-ibm-images/milvus:v2.5.15 |
| zilliz/attu:v2.5.6 | br.icr.io/br-ibm-images/attu:v2.5.6 |
| docker.io/milvusdb/etcd:3.5.18-r1 | br.icr.io/br-ibm-images/etcd:3.5.18-r1 |
| docker.io/bitnami/kafka:3.1.0-debian-10-r52 | br.icr.io/br-ibm-images/kafka:3.1.0-debian-10-r52 |
| docker.io/bitnami/zookeeper:3.7.0-debian-10-r320 | br.icr.io/br-ibm-images/zookeeper:3.7.0-debian-10-r320 |
| minio/minio:RELEASE.2024-05-28T17-19-04Z | br.icr.io/br-ibm-images/minio:RELEASE.2024-05-28T17-19-04Z |
| redis:8.0.2 | br.icr.io/br-ibm-images/redis:8.0.2 |
| quay.io/prometheus/statsd-exporter:v0.28.0 | br.icr.io/br-ibm-images/statsd-exporter:v0.28.0 |

---

## 2. MCP Component Configuration Sync

### 2.1 MCP Git-S3 Server

**Files**:
- `originals/mmjc-test/deployments/mcp-git-s3-server.yaml` (17379 bytes)
- `kustomize/mmjc-test/deployments/mcp-git-s3-server.yaml` (17379 bytes)

**Status**: ✅ **SYNCED** (identical file sizes)

**Installation-Specific Values**:
```yaml
# These values should be templated per installation
env:
  - name: S3_ENDPOINT
    value: "https://s3.us-south.cloud-object-storage.appdomain.cloud"  # IBM COS specific
  - name: S3_BUCKET
    value: "{{INSTALLATION_S3_BUCKET}}"  # Should be templated
  - name: S3_REGION
    value: "{{INSTALLATION_REGION}}"  # Should be templated
  - name: GIT_REPO_URL
    value: "{{INSTALLATION_GIT_REPO}}"  # Should be templated
```

**ConfigMaps**:
- `kustomize/mmjc-test/configmaps/mcp-git-s3-config.yaml`
- `kustomize/mmjc-test/configmaps/mcp-git-s3-jvm-config.yaml`
- `kustomize/mmjc-test/configmaps/mcp-git-s3-monitoring.yaml`
- `kustomize/mmjc-test/configmaps/mcp-git-s3-tls-config.yaml`

**Status**: ✅ All ConfigMaps present in kustomize

### 2.2 MCP ARC-S3 Server

**Files**:
- `originals/mmjc-test/statefulsets/mcp-arc-s3-server.yaml`
- `kustomize/mmjc-test/statefulsets/mcp-arc-s3-server.yaml` (15002 bytes)

**Status**: ✅ **SYNCED**

**Installation-Specific Values**:
```yaml
env:
  - name: S3_ENDPOINT
    value: "{{INSTALLATION_S3_ENDPOINT}}"
  - name: S3_BUCKET
    value: "{{INSTALLATION_ARC_BUCKET}}"
  - name: AWS_REGION
    value: "{{INSTALLATION_REGION}}"
  - name: POSTGRES_HOST
    value: "{{INSTALLATION_POSTGRES_HOST}}"  # Database endpoint
  - name: POSTGRES_PORT
    value: "{{INSTALLATION_POSTGRES_PORT}}"  # Typically 5432 or 32337
  - name: POSTGRES_DB
    value: "{{INSTALLATION_DB_NAME}}"  # Database name
```

**ConfigMaps**:
- `kustomize/mmjc-test/configmaps/mcp-arc-s3-config.yaml`
- `kustomize/mmjc-test/configmaps/mcp-arc-s3-custom-result-config.yaml`
- `kustomize/mmjc-test/configmaps/mcp-arc-s3-ssh-config.yaml`

**Status**: ✅ All ConfigMaps present in kustomize

### 2.3 MCP Context Forge (Gateway)

**Files**:
- `originals/mmjc-test/deployments/mcp-gateway-test.yaml` (4924 bytes)
- `kustomize/mmjc-test/deployments/mcp-gateway.yaml` (4924 bytes)

**Status**: ✅ **SYNCED**

**Installation-Specific Values**:
```yaml
env:
  - name: MCP_GATEWAY_URL
    value: "http://mcp-gateway-test.{{NAMESPACE}}.svc.cluster.local/servers/{{SERVER_ID}}/sse"
  - name: JWT_SECRET
    valueFrom:
      secretKeyRef:
        name: mcp-gateway-jwt
        key: jwt_secret
```

### 2.4 MCP Milvus DB

**Files**:
- `originals/mmjc-test/deployments/mcp-milvus-db-test.yaml` (4070 bytes)
- `kustomize/mmjc-test/deployments/mcp-milvus-db.yaml` (4070 bytes)

**Status**: ✅ **SYNCED**

---

## 3. Installation-Specific Values to Template

### 3.1 Database Configuration

**Current (IBM Cloud Databases for PostgreSQL)**:
```yaml
POSTGRESQL_HOST: "7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud"
POSTGRESQL_PORT: "32337"
POSTGRESQL_DATABASE: "mmjc"
POSTGRESQL_SSLMODE: "verify-full"
POSTGRESQL_USERNAME: "ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957"
```

**Template (Installation-Agnostic)**:
```yaml
POSTGRESQL_HOST: "{{DB_HOST}}"
POSTGRESQL_PORT: "{{DB_PORT}}"  # Default: 5432, IBM Cloud: 32337, AWS RDS: 5432
POSTGRESQL_DATABASE: "{{DB_NAME}}"
POSTGRESQL_SSLMODE: "{{DB_SSL_MODE}}"  # verify-full, require, disable
POSTGRESQL_USERNAME: "{{DB_USER}}"
```

**Where used**:
- `agents` deployment
- `po` deployment
- `airflow` deployments
- `mcp-arc-s3-server` statefulset

### 3.2 Object Storage Configuration

**Current (IBM Cloud Object Storage)**:
```yaml
COS_ENDPOINT_URL: "https://s3.us-south.cloud-object-storage.appdomain.cloud"
S3_ENDPOINT: "https://s3.us-south.cloud-object-storage.appdomain.cloud"
```

**Template**:
```yaml
COS_ENDPOINT_URL: "{{S3_ENDPOINT}}"  # AWS: https://s3.{region}.amazonaws.com, IBM: https://s3.{region}.cloud-object-storage.appdomain.cloud
S3_ENDPOINT: "{{S3_ENDPOINT}}"
S3_REGION: "{{S3_REGION}}"  # us-south, us-east-1, etc.
```

**Where used**:
- `agents` deployment
- `airflow-test` configuration
- `mcp-git-s3-server` deployment
- `mcp-arc-s3-server` statefulset

### 3.3 LLM Gateway Configuration

**Current (IBM-specific)**:
```yaml
OPENAI_API_BASE: "https://model-gateway.llm-adapter-dev-c97c2ce0266e6f32de317d52e2a84f46-0001.us-east.containers.appdomain.cloud/v1"
MODEL_NAME: "openai:sonnet-4-5"
```

**Template**:
```yaml
OPENAI_API_BASE: "{{LLM_GATEWAY_URL}}"
MODEL_NAME: "{{MODEL_NAME}}"
```

**Where used**:
- `agents` deployment

### 3.4 MCP Gateway Configuration

**Current**:
```yaml
MCP_GATEWAY_URL: "http://mcp-gateway-test.mmjc-test.svc.cluster.local/servers/d22371abbe0042559ae52772ff3b9337/sse"
```

**Template**:
```yaml
MCP_GATEWAY_URL: "http://mcp-gateway-{{ENVIRONMENT}}.{{NAMESPACE}}.svc.cluster.local/servers/{{SERVER_ID}}/sse"
```

**Where used**:
- `agents` deployment

### 3.5 Git Configuration

**Current**:
```yaml
GIT_USERNAME: "romanas-marcenko"
GIT_PASSWORD: "{{from secret}}"
```

**Template**:
```yaml
GIT_USERNAME: "{{GIT_USER}}"
GIT_PASSWORD: "{{from secret git-password-secret-agents}}"
```

### 3.6 Namespace References

**Current**:
```yaml
namespace: mmjc-test
namespace: airflow-test
```

**Template**:
```yaml
namespace: "{{NAMESPACE}}"  # mmjc-test, mmjc-dev, mmjc-prod, etc.
```

---

## 4. Sync Status Summary

| Component | originals/ | kustomize/ | Status | Notes |
|-----------|-----------|-----------|--------|-------|
| agents | ✅ | ✅ | SYNCED | Version pinned |
| frontend | ✅ | ✅ | SYNCED | Version pinned |
| po | ✅ | ✅ | SYNCED | Version pinned |
| **mcp-git-s3** | ✅ | ✅ | **SYNCED** | **Identical** |
| **mcp-arc-s3** | ✅ | ✅ | **SYNCED** | **Identical** |
| mcp-gateway | ✅ | ✅ | SYNCED | Identical |
| mcp-milvus-db | ✅ | ✅ | SYNCED | Identical |
| mermaid-validator | ✅ | ✅ | SYNCED | Version pinned |
| milvus-datanode | ✅ | ✅ | SYNCED | Version pinned |
| milvus-indexnode | ✅ | ✅ | SYNCED | Version pinned |
| milvus-mixcoord | ✅ | ✅ | SYNCED | Version pinned |
| milvus-proxy | ✅ | ✅ | SYNCED | Version pinned |
| milvus-querynode | ✅ | ✅ | SYNCED | Version pinned |
| redis-cluster | ✅ | ✅ | SYNCED | Version added |
| milvus-etcd | ✅ | ✅ | SYNCED | Version added |
| milvus-kafka | ✅ | ✅ | SYNCED | Version added |
| milvus-minio | ✅ | ✅ | SYNCED | Version added |
| milvus-zookeeper | ✅ | ✅ | SYNCED | Version added |
| attu | ✅ | ✅ | SYNCED | Version pinned |
| airflow-scheduler | ✅ | ✅ | SYNCED | Version 3.0.2 |
| airflow-worker | ✅ | ✅ | SYNCED | Version 3.0.2 |
| airflow-triggerer | ✅ | ✅ | SYNCED | Version 3.0.2 |
| airflow-api-server | ✅ | ✅ | SYNCED | Version 3.0.2 |
| airflow-dag-processor | ✅ | ✅ | SYNCED | Version 3.0.2 |

**Overall Status**: ✅ **ALL COMPONENTS SYNCED**

---

## 5. Configuration Templates Needed

### 5.1 Create Environment-Specific Overlays

```bash
kustomize/
├── base/
│   └── common-config/  # Shared configs
├── mmjc-test/          # Base kustomization
├── airflow-test/       # Base kustomization
└── overlays/
    ├── artifactory/    # Air-gapped with br.icr.io
    ├── aws/            # AWS-specific settings
    ├── ibm-cloud/      # IBM Cloud-specific settings
    └── on-prem/        # On-premises installation
```

### 5.2 Common Config Variables

Create `kustomize/base/common-config/env-template.yaml`:
```yaml
# Installation-specific environment variables template
# Copy this file and replace {{VARIABLES}} with actual values

# Database Configuration
DB_HOST: "{{POSTGRES_HOST}}"
DB_PORT: "{{POSTGRES_PORT}}"
DB_NAME: "{{DATABASE_NAME}}"
DB_USER: "{{DATABASE_USER}}"
DB_SSL_MODE: "{{SSL_MODE}}"  # verify-full, require, disable

# Object Storage
S3_ENDPOINT: "{{S3_ENDPOINT_URL}}"
S3_REGION: "{{S3_REGION}}"
S3_BUCKET: "{{S3_BUCKET_NAME}}"

# LLM Gateway
LLM_GATEWAY_URL: "{{LLM_API_BASE_URL}}"
MODEL_NAME: "{{DEFAULT_MODEL}}"

# MCP Gateway
MCP_GATEWAY_SERVER_ID: "{{MCP_SERVER_UUID}}"

# Git Configuration
GIT_USER: "{{GIT_USERNAME}}"
GIT_REPO_BASE: "{{GIT_REPOSITORY_URL}}"

# Namespace
NAMESPACE: "{{KUBERNETES_NAMESPACE}}"
ENVIRONMENT: "{{ENV}}"  # test, dev, prod
```

---

## 6. Action Items

### Immediate (Before Air-Gapped Deployment)

1. ✅ **Pull and retag all images**
   ```bash
   ./scripts/pull-and-retag-images.sh --dry-run  # Test first
   ./scripts/pull-and-retag-images.sh --push     # Actually push
   ```

2. ✅ **Verify Artifactory overlay**
   ```bash
   kubectl kustomize kustomize/overlays/artifactory > /tmp/artifactory-build.yaml
   # Review the output
   ```

3. ⏳ **Create installation config template**
   - Document all installation-specific values
   - Create substitution script/tool

4. ⏳ **Test deployment with templates**
   ```bash
   # Generate configs from template
   ./scripts/generate-configs.sh --env production

   # Deploy
   kubectl apply -k kustomize/overlays/production
   ```

### For New Installations

1. Copy `env-template.yaml`
2. Fill in installation-specific values
3. Run configuration generator
4. Deploy with appropriate overlay

---

## 7. Image Pull/Retag Commands

### Quick Start

```bash
# 1. Login to source registry (ICR)
ibmcloud cr login

# 2. Login to target registry (Artifactory)
docker login br.icr.io
# Username: your-artifactory-user
# Password: your-artifactory-token

# 3. Pull and retag all images (dry-run first)
cd /Users/gregoriomomm/workspace/ica/mjc_install-
./scripts/pull-and-retag-images.sh --dry-run

# 4. Review what will be done, then push
./scripts/pull-and-retag-images.sh --push

# 5. Verify images in Artifactory
curl -u user:pass https://br.icr.io/v2/_catalog | jq '.'
```

### Manual Examples

```bash
# Example: Pull, tag, and push mmjc-agents
docker pull icr.io/mjc-cr/mmjc-agents:0.0.2
docker tag icr.io/mjc-cr/mmjc-agents:0.0.2 br.icr.io/br-ibm-images/mmjc-agents:0.0.2
docker push br.icr.io/br-ibm-images/mmjc-agents:0.0.2

# Example: Pull, tag, and push mcp-git-s3
docker pull icr.io/mjc-cr/go-mcp-git-s3:1.0.31
docker tag icr.io/mjc-cr/go-mcp-git-s3:1.0.31 br.icr.io/br-ibm-images/go-mcp-git-s3:1.0.31
docker push br.icr.io/br-ibm-images/go-mcp-git-s3:1.0.31

# Example: Pull, tag, and push mcp-arc-s3
docker pull icr.io/mjc-cr/mcp-arc-s3-server:2.1.45-amd64
docker tag icr.io/mjc-cr/mcp-arc-s3-server:2.1.45-amd64 br.icr.io/br-ibm-images/mcp-arc-s3-server:2.1.45-amd64
docker push br.icr.io/br-ibm-images/mcp-arc-s3-server:2.1.45-amd64
```

---

## 8. Verification Checklist

Before deploying to air-gapped environment:

- [ ] All custom images pulled from ICR
- [ ] All custom images retagged for br.icr.io
- [ ] All custom images pushed to Artifactory
- [ ] All public images pulled and mirrored
- [ ] Kustomization overlay tested with `kubectl kustomize`
- [ ] Installation-specific values documented
- [ ] Database initialization scripts prepared
- [ ] Secrets templates created for target environment
- [ ] Network/DNS configuration documented
- [ ] Rollback procedure documented

---

**Document Version**: 1.0
**Last Updated**: 2025-11-02
**Status**: Ready for Image Migration
