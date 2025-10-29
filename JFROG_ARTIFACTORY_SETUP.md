# 🔧 JFrog Artifactory Configuration

**Purpose**: Configure JFrog Artifactory as a proxy/mirror for IBM Container Registry
**Benefits**: Centralized image management, caching, security scanning

---

## 📋 Overview

With JFrog Artifactory configured, your images will be accessible via:

```
Direct (IBM CR):
  br.icr.io/br-ibm-images/mmjc-bff-v2:0.0.2

Via JFrog Artifactory:
  artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-bff-v2:0.0.2
```

---

## 🎯 How to Apply JFrog Prefix

### Method 1: Environment Variable (Recommended)

```bash
# Before running migration
export JFROG_PREFIX="artifactory.yourcompany.com/ibm-cr-remote/"
export JFROG_ENABLED=true

# Run migration
./scripts/migrate-images-manual.sh
```

### Method 2: Configuration File

```bash
# Edit config file
vim config/migration.env

# Add these lines:
JFROG_PREFIX=artifactory.yourcompany.com/ibm-cr-remote/
JFROG_ENABLED=true

# Save and run migration
./scripts/migrate-images-manual.sh
```

### Method 3: Create config/migration.env

```bash
# Create from example
cp config/migration.env.example config/migration.env

# Edit the file
vim config/migration.env

# Find and uncomment these lines:
TARGET_ICR_REGION=br.icr.io
TARGET_NAMESPACE=br-ibm-images
TARGET_REGISTRY=br.icr.io/br-ibm-images

# Add JFrog configuration:
JFROG_PREFIX=artifactory.yourcompany.com/ibm-cr-remote/
JFROG_ENABLED=true

# Save and run
./scripts/migrate-images-manual.sh
```

---

## 🔧 JFrog Artifactory Setup (Prerequisites)

### 1. Create Remote Repository in JFrog

**In JFrog Artifactory UI**:

1. Navigate to **Administration** → **Repositories** → **Remote**
2. Click **New Remote Repository**
3. Select **Docker**
4. Configure:

```yaml
Repository Key: ibm-cr-remote
URL: https://br.icr.io
Registry Type: Docker Registry V2
Enable Token Authentication: Yes
```

5. **Authentication** (if needed):
   - Username: `iamapikey`
   - Password: `<IBM Cloud API Key>`

6. Click **Create**

### 2. Verify Remote Repository

```bash
# Test access
docker login artifactory.yourcompany.com
docker pull artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mjc-mermaid-validator:1.0.17
```

---

## 📝 What Happens When JFROG_PREFIX is Set

### During Migration:

The script will:
1. ✅ Migrate images to `br.icr.io/br-ibm-images/` (as usual)
2. ✅ Display JFrog access paths in output
3. ✅ Document JFrog URLs in summary

### Example Output:

```
[3/7] Determining target registry...
   Target IBM Registry: br.icr.io
   Target Namespace: br-ibm-images
   JFrog Artifactory Prefix: artifactory.yourcompany.com/ibm-cr-remote/
   Images will be accessible via: artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images

   Target Registry: br.icr.io/br-ibm-images

[6/7] Migrating images...

📦 Migrating: us.icr.io/mmjc-cr/mmjc-bff-v2:0.0.2
   → Target: br.icr.io/br-ibm-images/mmjc-bff-v2:0.0.2
   → JFrog:  artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-bff-v2:0.0.2
```

---

## 🎯 Using Images from JFrog

### In Kubernetes Manifests:

```yaml
# Option 1: Direct from IBM CR
spec:
  containers:
  - name: app
    image: br.icr.io/br-ibm-images/mmjc-bff-v2:0.0.2

# Option 2: Via JFrog Artifactory
spec:
  containers:
  - name: app
    image: artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-bff-v2:0.0.2
```

### Pull from JFrog:

```bash
# Login to JFrog
docker login artifactory.yourcompany.com

# Pull image
docker pull artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-bff-v2:0.0.2
```

---

## 📋 Full Configuration Example

### config/migration.env

```bash
# ==========================================
# IBM Cloud Container Registry Configuration
# ==========================================

# Target Registry (Brazil Region)
TARGET_ICR_REGION=br.icr.io
TARGET_NAMESPACE=br-ibm-images
TARGET_REGISTRY=br.icr.io/br-ibm-images

# Source Registry (US Region)
SOURCE_REGISTRY=us.icr.io/mmjc-cr

# ==========================================
# JFrog Artifactory Configuration
# ==========================================

# JFrog Artifactory Base URL
JFROG_BASE_URL=artifactory.yourcompany.com

# JFrog Remote Repository Name (points to br.icr.io)
JFROG_REMOTE_REPO=ibm-cr-remote

# Full JFrog Prefix (composed from above)
JFROG_PREFIX=${JFROG_BASE_URL}/${JFROG_REMOTE_REPO}/

# Enable JFrog documentation in output
JFROG_ENABLED=true

# ==========================================
# Example Values for Your Company
# ==========================================

# Replace with your actual JFrog URL:
# JFROG_PREFIX=jfrog.itau.com.br/docker-remote-ibm-cr/
# JFROG_PREFIX=artifactory-prod.company.com/ibm-container-registry/
```

---

## 🔍 Verification

### Test JFrog Access:

```bash
# 1. Login to JFrog
docker login artifactory.yourcompany.com

# 2. Pull via JFrog (should proxy to br.icr.io)
docker pull artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mjc-mermaid-validator:1.0.17

# 3. Verify it's the same image
docker images | grep mjc-mermaid-validator

# Should show:
# br.icr.io/br-ibm-images/mjc-mermaid-validator                              1.0.17    ...
# artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mjc-mermaid-validator   1.0.17    ... (same ID)
```

---

## 🏗️ Architecture with JFrog

```
┌────────────────────────────────────────────────────────┐
│ KUBERNETES CLUSTER                                     │
│                                                        │
│ Pods pull images from:                                │
│  Option A: br.icr.io/br-ibm-images/* (direct)         │
│  Option B: artifactory.../ibm-cr-remote/... (via proxy)│
└────────────────────────────────────────────────────────┘
                      ↓                ↓
        ┌─────────────────┐  ┌──────────────────┐
        │   Direct Path   │  │   JFrog Path     │
        └─────────────────┘  └──────────────────┘
                ↓                     ↓
    ┌────────────────────┐  ┌────────────────────────┐
    │ IBM Container      │←─│ JFrog Artifactory      │
    │ Registry           │  │ (Remote Repository)    │
    │ br.icr.io          │  │ Caches & proxies       │
    │                    │  │ br.icr.io              │
    └────────────────────┘  └────────────────────────┘
```

---

## 💡 Benefits of Using JFrog

1. **Caching**: JFrog caches images locally, faster pulls
2. **Security**: Scan images before deployment
3. **Governance**: Control which images can be used
4. **Metrics**: Track image usage and downloads
5. **High Availability**: JFrog handles failover
6. **Bandwidth**: Reduced external bandwidth usage

---

## 🆘 Troubleshooting

### Issue: Cannot pull from JFrog

**Check**:
```bash
# 1. JFrog remote repository configured?
curl -u admin:password https://artifactory.yourcompany.com/artifactory/api/repositories/ibm-cr-remote

# 2. Can JFrog reach br.icr.io?
# Test from JFrog server

# 3. Authentication correct?
docker login artifactory.yourcompany.com
```

### Issue: Images not syncing

**Solution**: Check JFrog remote repository settings:
- URL: `https://br.icr.io` (correct)
- Authentication: IAM API key from IBM Cloud
- Enable metadata retrieval

### Issue: JFROG_PREFIX not working

**Check**:
```bash
# 1. Variable set?
echo $JFROG_PREFIX

# 2. Trailing slash?
# Should be: artifactory.com/repo/
# NOT:       artifactory.com/repo

# 3. Config file loaded?
cat config/migration.env | grep JFROG
```

---

## 📊 Summary

### Without JFrog:
```
Image: br.icr.io/br-ibm-images/mmjc-bff-v2:0.0.2
Pull:  Direct from IBM CR
```

### With JFrog:
```
Image:     br.icr.io/br-ibm-images/mmjc-bff-v2:0.0.2
Also via:  artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/mmjc-bff-v2:0.0.2
Pull:      Via JFrog (cached, scanned, governed)
```

---

## ✅ Quick Setup

```bash
# 1. Set JFrog prefix
export JFROG_PREFIX="artifactory.yourcompany.com/ibm-cr-remote/"
export JFROG_ENABLED=true

# 2. Run migration
./scripts/migrate-images-manual.sh

# 3. Images will be documented with both paths:
#    - Direct: br.icr.io/br-ibm-images/*
#    - JFrog:  artifactory.yourcompany.com/ibm-cr-remote/br-ibm-images/*
```

---

**Next**: Configure JFrog remote repository, then set `JFROG_PREFIX` and run migration!
