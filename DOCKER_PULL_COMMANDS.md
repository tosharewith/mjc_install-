# 🐳 Docker Pull Commands - Migrated Images

**Registry**: `br.icr.io/br-ibm-images/`
**Region**: Brazil (São Paulo)
**Date**: 2025-10-29

---

## 📦 All Migrated Images

### Quick Copy-Paste (All 14 Images):

```bash
# Airflow Service (1)
docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest

# MCP Services (4)
docker pull br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64
docker pull br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1
docker pull br.icr.io/br-ibm-images/mcp-context-forge:0.6.0
docker pull br.icr.io/br-ibm-images/go-mcp-git-s3:1.0.31

# Validators (1)
docker pull br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64

# MMJC Services (3)
docker pull br.icr.io/br-ibm-images/mmjc-po:0.0.1
docker pull br.icr.io/br-ibm-images/mmjc-agents:0.0.1
docker pull br.icr.io/br-ibm-images/mmjc-frontend:0.0.1

# File Services (2)
docker pull br.icr.io/br-ibm-images/api-file-zip-s3:1.0.2
docker pull br.icr.io/br-ibm-images/cos-file-organizer:0.1.0

# Understanding Agent (1)
docker pull br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57
```

---

## 📋 By Deployment

### For Airflow (airflow-test namespace):

```bash
docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest
```

**Used in**:
- airflow-scheduler
- airflow-webserver
- airflow-worker
- airflow-triggerer
- git-sync (init container)

---

### For Milvus (milvus-mmjc-dev namespace):

```bash
# MCP Services
docker pull br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64
docker pull br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1

# Validators
docker pull br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64

# MMJC Services
docker pull br.icr.io/br-ibm-images/mmjc-po:0.0.1

# Understanding Agent
docker pull br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5
docker pull br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57
```

---

## 🔐 Login Required

Before pulling images, authenticate with IBM Cloud Container Registry:

```bash
# Option 1: Using IBM Cloud CLI
ibmcloud cr login

# Option 2: Using Docker with API Key
docker login br.icr.io -u iamapikey -p <YOUR_IBM_CLOUD_API_KEY>
```

---

## ✅ Verify Images

After pulling, verify images:

```bash
docker images | grep "br.icr.io/br-ibm-images"
```

Expected output:

```
br.icr.io/br-ibm-images/mmjc-airflow-service               latest          <image-id>    <date>    <size>
br.icr.io/br-ibm-images/mcp-arc-s3-tool                    2.1.17-amd64    <image-id>    <date>    <size>
br.icr.io/br-ibm-images/mcp-milvus-db                      0.0.1           <image-id>    <date>    <size>
br.icr.io/br-ibm-images/mjc-mermaid-validator              1.0.17-llm...   <image-id>    <date>    <size>
br.icr.io/br-ibm-images/mmjc-po                            0.0.1           <image-id>    <date>    <size>
br.icr.io/br-ibm-images/understanding-agent-arc            1.5.5           <image-id>    <date>    <size>
br.icr.io/br-ibm-images/understanding-agent-arc            v1.6.57         <image-id>    <date>    <size>
```

---

## 🌍 List All Images in Registry

To see all available images in the Brazil registry:

```bash
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images
```

---

## 📝 Image Details

| Image | Tag | Source | Architecture | Purpose |
|-------|-----|--------|--------------|---------|
| mmjc-airflow-service | latest | icr.io/mjc-cr | amd64 | Apache Airflow service |
| mcp-arc-s3-tool | 2.1.17-amd64 | icr.io/mjc-cr | amd64 | MCP Arc S3 integration tool |
| mcp-milvus-db | 0.0.1 | icr.io/mjc-cr | amd64 | MCP Milvus database connector |
| mjc-mermaid-validator | 1.0.17-llm-ready-amd64 | icr.io/mjc-cr | amd64 | Mermaid diagram validator |
| mmjc-po | 0.0.1 | icr.io/mjc-cr | amd64 | MMJC PO service |
| understanding-agent-arc | 1.5.5 | icr.io/mjc-cr | amd64 | Understanding agent (older) |
| understanding-agent-arc | v1.6.57 | icr.io/mjc-cr | amd64 | Understanding agent (latest) |

---

## 🔧 Optional: JFrog Artifactory

If using JFrog Artifactory as proxy, images are also accessible via:

```bash
# Example (replace with your JFrog URL)
docker pull artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-airflow-service:latest
```

See: [JFROG_ARTIFACTORY_SETUP.md](JFROG_ARTIFACTORY_SETUP.md) for configuration.

---

## 📊 Script to Pull All Images

Save this as `pull-all-images.sh`:

```bash
#!/bin/bash
# Pull all migrated images from Brazil registry

set -e

echo "🐳 Pulling all images from br.icr.io/br-ibm-images..."
echo ""

# Login
echo "Logging into IBM CR..."
ibmcloud cr login

# Pull all images
IMAGES=(
    "br.icr.io/br-ibm-images/mmjc-airflow-service:latest"
    "br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64"
    "br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1"
    "br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64"
    "br.icr.io/br-ibm-images/mmjc-po:0.0.1"
    "br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5"
    "br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57"
)

for IMAGE in "${IMAGES[@]}"; do
    echo "Pulling: $IMAGE"
    docker pull "$IMAGE"
    echo ""
done

echo "✅ All images pulled successfully!"
docker images | grep "br.icr.io/br-ibm-images"
```

Make executable and run:

```bash
chmod +x pull-all-images.sh
./pull-all-images.sh
```

---

## 🆘 Troubleshooting

### Cannot pull images?

1. **Check login**:
   ```bash
   ibmcloud cr login
   ```

2. **Check region**:
   ```bash
   ibmcloud cr region-set br.icr.io
   ```

3. **Check permissions**:
   ```bash
   ibmcloud cr images --restrict br-ibm-images
   ```

4. **Verify network connectivity**:
   ```bash
   ping br.icr.io
   ```

### Images not found?

Verify they exist:
```bash
ibmcloud cr region-set br.icr.io
ibmcloud cr images --restrict br-ibm-images | grep "<image-name>"
```

---

## 📞 Share With Team

Send these commands to your team:

```
Hi team,

Our custom images have been migrated to the Brazil region registry:

Registry: br.icr.io/br-ibm-images/

To pull all images, run:

# Login first
ibmcloud cr login

# Pull images (copy-paste entire block)
docker pull br.icr.io/br-ibm-images/mmjc-airflow-service:latest
docker pull br.icr.io/br-ibm-images/mcp-arc-s3-tool:2.1.17-amd64
docker pull br.icr.io/br-ibm-images/mcp-milvus-db:0.0.1
docker pull br.icr.io/br-ibm-images/mjc-mermaid-validator:1.0.17-llm-ready-amd64
docker pull br.icr.io/br-ibm-images/mmjc-po:0.0.1
docker pull br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5
docker pull br.icr.io/br-ibm-images/understanding-agent-arc:v1.6.57

Full documentation: <repo-url>/DOCKER_PULL_COMMANDS.md
```

---

**Last Updated**: 2025-10-29
**Registry**: br.icr.io/br-ibm-images
**Total Images**: 7
