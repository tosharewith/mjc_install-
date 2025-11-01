# Installation Guide - Kubernetes Deployment with Kustomize

Complete guide for deploying applications using the extracted Kubernetes resources with Kustomize and centralized configuration.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Installation Methods](#installation-methods)
5. [Configuration Management](#configuration-management)
6. [Secret Management](#secret-management)
7. [Image Registry Configuration](#image-registry-configuration)
8. [Deployment](#deployment)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This repository provides **three ways** to deploy Kubernetes resources:

| Method | Use Case | Complexity |
|--------|----------|------------|
| **Kustomize** (Recommended) | Production, with centralized config | Medium |
| **kubectl apply** | Quick testing, direct deployment | Low |
| **Helm conversion** | Advanced, GitOps integration | High |

**Recommended:** Use **Kustomize** for production deployments with centralized configuration management.

---

## Prerequisites

### Required Tools

```bash
# Kubernetes CLI
kubectl version --client
# Required: v1.24+

# Kustomize (built into kubectl)
kubectl kustomize --help

# Optional: Standalone kustomize
kustomize version
# Recommended: v5.0+
```

### Cluster Access

```bash
# Verify cluster connection
kubectl cluster-info

# Check namespaces
kubectl get namespaces
```

### Storage Classes

Verify required storage classes exist:

```bash
kubectl get storageclass

# Required storage classes:
# - ibmc-vpc-block-10iops-tier (or equivalent block storage)
# - ibmc-s3fs-smart-perf-regional (or equivalent S3-backed storage)
```

---

## Quick Start

### 1. Repository Structure

```
.
├── originals/              # Extracted resources from cluster
│   ├── airflow-test/
│   ├── mmjc-test/
│   ├── mmjc-dev/
│   └── secret-templates/   # Safe secret templates
│
└── kustomize/              # Kustomize-ready deployments
    ├── base/
    │   └── common-config/  # ✨ Centralized configuration
    ├── airflow-test/
    ├── mmjc-test/
    └── overlays/
        ├── artifactory/    # For Artifactory registry
        └── air-gapped/     # For air-gapped environments
```

### 2. Configure Common Settings

**Edit centralized configuration:**

```bash
# S3 / Object Storage
vim kustomize/base/common-config/s3-config.env

# LLM / AI Models
vim kustomize/base/common-config/llm-config.env

# Database Connections
vim kustomize/base/common-config/database-config.env

# Application Settings
vim kustomize/base/common-config/application-config.env
```

### 3. Configure Image Registry

```bash
# Option 1: Use helper script
./kustomize/change-image-registry.sh mmjc-test \
  icr.io/mjc-cr \
  br.icr.io/br-ibm-images

# Option 2: Edit kustomization.yaml
vim kustomize/mmjc-test/kustomization.yaml

# Option 3: Use pre-configured overlay
kubectl apply -k kustomize/overlays/artifactory/
```

### 4. Deploy

```bash
# Preview what will be deployed
kubectl kustomize kustomize/mmjc-test/

# Deploy to cluster
kubectl apply -k kustomize/mmjc-test/

# Verify deployment
kubectl get all -n mmjc-test
```

---

## Installation Methods

### Method 1: Kustomize Deployment (Recommended)

**Advantages:**
- ✅ Centralized configuration management
- ✅ Easy image registry changes
- ✅ Environment-specific overlays
- ✅ GitOps friendly
- ✅ Automatic ConfigMap/Secret generation

**Steps:**

```bash
# 1. Preview deployment
kubectl kustomize kustomize/mmjc-test/ | less

# 2. Validate resources
kubectl apply -k kustomize/mmjc-test/ --dry-run=client

# 3. Deploy
kubectl apply -k kustomize/mmjc-test/

# 4. Watch deployment
kubectl get pods -n mmjc-test -w
```

### Method 2: Direct kubectl apply

**Advantages:**
- ✅ Simple and straightforward
- ✅ Good for testing
- ✅ Direct control

**Steps:**

```bash
# Deploy in order
kubectl apply -f originals/mmjc-test/configmaps/
kubectl apply -f originals/mmjc-test/pvcs/
kubectl apply -f originals/mmjc-test/services/
kubectl apply -f originals/mmjc-test/deployments/
kubectl apply -f originals/mmjc-test/statefulsets/
kubectl apply -f originals/mmjc-test/ingresses/
```

**⚠️ Important:** For secrets, use `originals/secret-templates/` (after replacing placeholders)

### Method 3: Environment-Specific Overlays

**For multiple environments (dev/staging/prod):**

```bash
# Deploy to development
kubectl apply -k kustomize/overlays/dev/

# Deploy to staging
kubectl apply -k kustomize/overlays/staging/

# Deploy to production
kubectl apply -k kustomize/overlays/prod/
```

---

## Configuration Management

### Centralized Configuration (⭐ Key Feature)

All common configuration is centralized in **ONE location:**

```
kustomize/base/common-config/
├── s3-config.env              # S3 endpoints, buckets
├── llm-config.env             # LLM/AI settings
├── database-config.env        # Database connections
└── application-config.env     # General settings
```

**Benefits:**
- ✅ Update S3 endpoint → Affects all services
- ✅ Change LLM model → Update once
- ✅ No configuration duplication
- ✅ Guaranteed consistency

### Using Centralized Config

See `kustomize/base/common-config/README.md` for complete documentation.

**Quick Example:**

Edit deployment to inject all S3 configuration:

```yaml
spec:
  containers:
  - name: my-app
    envFrom:
      - configMapRef:
          name: s3-config
      - secretRef:
          name: s3-credentials
```

---

## Secret Management

### Development/Testing (Quick)

```bash
# Edit kustomization.yaml
vim kustomize/base/common-config/kustomization.yaml

# Update secretGenerator section with actual values
```

### Production (Recommended)

#### Option 1: External Secrets Operator

```bash
# Install
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace

# Configure with Vault/AWS/GCP
# See: https://external-secrets.io/
```

#### Option 2: Sealed Secrets

```bash
# Install Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal

# Seal a secret
kubeseal -f secret.yaml -w sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

#### Option 3: Manual from Templates

```bash
# 1. Copy template
cp originals/secret-templates/mmjc-test/postgresql-secret-test.yaml my-secrets/

# 2. Replace placeholders (base64 encode your values)
echo -n "my-password" | base64

# 3. Edit file and replace <REPLACE_WITH_BASE64_ENCODED_*>

# 4. Apply
kubectl apply -f my-secrets/postgresql-secret-test.yaml
```

---

## Image Registry Configuration

### Scenario 1: Change to Artifactory

```bash
# Method 1: Helper script
./kustomize/change-image-registry.sh mmjc-test \
  icr.io/mjc-cr \
  br.icr.io/br-ibm-images

# Method 2: Use pre-configured overlay
kubectl apply -k kustomize/overlays/artifactory/
```

### Scenario 2: Air-Gapped Environment

```bash
# Use air-gapped overlay (all images from internal registry)
kubectl apply -k kustomize/overlays/air-gapped/
```

### Scenario 3: Custom Registry

```bash
# Edit kustomization.yaml
vim kustomize/mmjc-test/kustomization.yaml

# Update images section
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: my-registry.com/mmjc-agents
    newTag: 1.0.0
```

**See:** `kustomize/README.md` for details.

---

## Deployment

### Pre-Deployment Checklist

```bash
# ✅ 1. Verify cluster access
kubectl cluster-info

# ✅ 2. Check namespace
kubectl get namespace mmjc-test || kubectl create namespace mmjc-test

# ✅ 3. Verify storage classes
kubectl get storageclass

# ✅ 4. Check image pull secrets
kubectl get secret all-icr-io-mmjc -n mmjc-test

# ✅ 5. Validate kustomize
kubectl kustomize kustomize/mmjc-test/ | kubectl apply --dry-run=client -f -
```

### Deployment Steps

```bash
# Step 1: Deploy (common-config included automatically)
kubectl apply -k kustomize/mmjc-test/

# Step 2: Watch progress
kubectl get pods -n mmjc-test -w

# Step 3: Verify
kubectl get all -n mmjc-test
```

### Rolling Updates

```bash
# Update configuration
vim kustomize/base/common-config/s3-config.env

# Apply (pods restart automatically)
kubectl apply -k kustomize/mmjc-test/
```

---

## Verification

### Health Checks

```bash
# Check pods
kubectl get pods -n mmjc-test

# Check deployments
kubectl get deployments -n mmjc-test

# Check services
kubectl get svc -n mmjc-test

# Check configmaps
kubectl get configmap -n mmjc-test | grep -E "(s3|llm|database)"
```

### Connectivity Tests

```bash
# Test internal service
kubectl run test --rm -i --tty --image=busybox -n mmjc-test -- \
  wget -O- http://agents-mmjc-test

# Check logs
kubectl logs -n mmjc-test deployment/agents-mmjc-test
```

---

## Troubleshooting

### Common Issues

#### ImagePullBackOff

```bash
# Check image pull secret
kubectl get secret all-icr-io-mmjc -n mmjc-test

# Verify image name
kubectl describe pod <pod-name> -n mmjc-test | grep Image
```

#### CrashLoopBackOff

```bash
# Check logs
kubectl logs -n mmjc-test <pod-name> --previous

# Check events
kubectl get events -n mmjc-test --sort-by='.lastTimestamp'
```

#### PVC Pending

```bash
# Check PVC
kubectl describe pvc <pvc-name> -n mmjc-test

# Verify storage class exists
kubectl get storageclass
```

#### ConfigMap Not Found

```bash
# List ConfigMaps
kubectl get configmap -n mmjc-test

# Rebuild
kubectl apply -k kustomize/base/common-config/
```

### Debugging Commands

```bash
# Get all events
kubectl get events -n mmjc-test --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n mmjc-test

# Describe resources
kubectl describe all -n mmjc-test

# Export current state
kubectl get all -n mmjc-test -o yaml > current-state.yaml
```

---

## Additional Resources

### Documentation

- [EXTRACTION_SUMMARY.md](EXTRACTION_SUMMARY.md) - Complete overview
- [kustomize/README.md](kustomize/README.md) - Kustomize guide
- [kustomize/COMMON_CONFIG_GUIDE.md](kustomize/COMMON_CONFIG_GUIDE.md) - Common config
- [originals/README.md](originals/README.md) - Original YAMLs
- [SECURITY_FIX_SECRETS.md](SECURITY_FIX_SECRETS.md) - Security info

### Helper Scripts

- `./kustomize/change-image-registry.sh` - Change registries
- `./kustomize/validate.sh` - Validate configs
- `./originals/template-secrets-perl.sh` - Template secrets
- `./extract-all-resources.sh` - Extract resources
- `./verify-extraction.sh` - Verify extraction

### External Links

- [Kustomize Documentation](https://kustomize.io/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)

---

**Last Updated:** 2025-10-31
**Version:** 1.0.0
**Status:** Production Ready ✅
