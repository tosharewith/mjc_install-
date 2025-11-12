# IBM Cloud to AWS Migration Sync Plan

**Source**: IBM Cloud Kubernetes (mjc-cluster)
**Target**: AWS EKS
**Date**: 2025-11-02
**Status**: Planning Phase

---

## Executive Summary

This document outlines the complete synchronization and migration plan for moving the MMJC application stack from IBM Cloud to AWS. The migration involves:

- **2 Namespaces**: `mmjc-test`, `airflow-test`
- **41 Pods** total (35 in mmjc-test, 6 in airflow-test)
- **220+ Kubernetes resources**
- **2 PostgreSQL databases** (shared instance)
- **Multiple external dependencies** (Object Storage, LLM gateways, etc.)

---

## Table of Contents

1. [Pre-Migration Checklist](#1-pre-migration-checklist)
2. [Database Migration](#2-database-migration)
3. [Object Storage Migration](#3-object-storage-migration)
4. [Image Registry Migration](#4-image-registry-migration)
5. [Kubernetes Resources Sync](#5-kubernetes-resources-sync)
6. [Configuration Updates](#6-configuration-updates)
7. [Network and DNS](#7-network-and-dns)
8. [Testing and Validation](#8-testing-and-validation)
9. [Rollback Plan](#9-rollback-plan)
10. [Post-Migration Tasks](#10-post-migration-tasks)

---

## 1. Pre-Migration Checklist

### 1.1 Current State Documentation

- [x] **Gap Analysis Completed** - See `GAP_ANALYSIS_REPORT.md`
- [x] **Image versions catalogued** - All versions documented
- [x] **Secret templates extracted** - 25 secrets (mmjc-test), 9 secrets (airflow-test)
- [ ] **Database schema exported** - Need to run pg_dump
- [ ] **Current resource usage metrics** - Collect CPU/Memory baselines
- [ ] **External dependencies mapped** - LLM gateway, Git repos, etc.

### 1.2 AWS Environment Setup

```bash
# Required AWS Resources
- [ ] EKS Cluster provisioned
- [ ] RDS PostgreSQL 16.8 instance created
- [ ] S3 buckets created (replacements for IBM COS)
- [ ] ECR repositories created (or continue using ICR)
- [ ] VPC and networking configured
- [ ] IAM roles and policies created
- [ ] Route53 DNS zones configured
```

### 1.3 Prerequisites

```bash
# Tools needed
- kubectl (configured for both clusters)
- aws-cli
- helm
- kustomize >= 4.x
- psql (PostgreSQL client)
- ibmcloud CLI (for source cluster)
```

---

## 2. Database Migration

### 2.1 Database Inventory

**Source**: IBM Cloud Databases for PostgreSQL
- **Host**: `7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud`
- **Port**: 32337
- **Database**: `mmjc` (shared by agents and other services)
- **Version**: PostgreSQL 16.8
- **Used by**:
  - Airflow (metadata DB)
  - mmjc-agents (LangGraph checkpoints)
  - mmjc-po (application data)

### 2.2 Critical Issues to Fix BEFORE Migration

⚠️ **HIGH PRIORITY**: Fix Airflow database connection scheme

```bash
# Current Airflow connection uses postgres:// (deprecated)
# Must change to postgresql:// before migration

# Fix command (run on IBM Cloud cluster):
kubectl exec -n airflow-test deployment/airflow-test-scheduler -- bash -c '
  current=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN)
  fixed=$(echo $current | sed "s|^postgres://|postgresql://|")
  echo "Old: $current"
  echo "New: $fixed"
'

# Update secret:
current=$(kubectl get secret -n airflow-test airflow-postgres-connection-test \
  -o jsonpath='{.data.connection}' | base64 -d)
fixed=$(echo "$current" | sed 's|^postgres://|postgresql://|')
echo -n "$fixed" | base64 | kubectl patch secret airflow-postgres-connection-test \
  -n airflow-test --type='json' \
  -p='[{"op": "replace", "path": "/data/connection", "value": "'$(echo -n "$fixed" | base64)'"}]'

# Restart Airflow components
kubectl rollout restart deployment -n airflow-test
kubectl rollout restart statefulset -n airflow-test
```

### 2.3 Initialize Missing Tables

⚠️ **CRITICAL**: Create missing `checkpoints` table for LangGraph

```bash
# The agents are failing because checkpoints table doesn't exist
# Run the initialization job:

# Option 1: Using Kubernetes Job (recommended)
kubectl apply -f kustomize/mmjc-test/jobs/init-database.yaml

# Wait for completion
kubectl wait --for=condition=complete job/init-mmjc-database -n mmjc-test --timeout=300s

# Check logs
kubectl logs -n mmjc-test job/init-mmjc-database

# Option 2: Manual SQL execution
kubectl run psql-client --rm -i --tty \
  --image=postgres:16.8 \
  --env="PGPASSWORD=$DB_PASSWORD" \
  -- psql -h $DB_HOST -p 32337 -U $DB_USER -d mmjc \
  -f /path/to/database/init-mmjc-database.sql
```

### 2.4 Database Migration Steps

```bash
# Step 1: Create dump from IBM Cloud PostgreSQL
# Run this from a location with network access to IBM Cloud DB

export IBM_DB_HOST="7bce9b8c-e602-4ae6-8a44-ad87cc332d96.c9v3nahd0oekcvsra2t0.private.databases.appdomain.cloud"
export IBM_DB_PORT="32337"
export IBM_DB_USER="ibm_cloud_971c0f4f_db43_4a27_9d6b_45d548902957"
export IBM_DB_NAME="mmjc"
export PGPASSWORD="Nugd0ujO9lVl3LyIyftqAKdCmP2tPW63"  # Use from secret

# Create dump
pg_dump -h $IBM_DB_HOST \
        -p $IBM_DB_PORT \
        -U $IBM_DB_USER \
        -d $IBM_DB_NAME \
        --no-owner \
        --no-acl \
        -Fc \
        -f mmjc-database-backup-$(date +%Y%m%d).dump

# Create schema-only dump (for faster testing)
pg_dump -h $IBM_DB_HOST \
        -p $IBM_DB_PORT \
        -U $IBM_DB_USER \
        -d $IBM_DB_NAME \
        --schema-only \
        --no-owner \
        --no-acl \
        -f mmjc-database-schema.sql

# Step 2: Setup AWS RDS PostgreSQL 16.8
aws rds create-db-instance \
  --db-instance-identifier mmjc-production \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 16.8 \
  --master-username admin \
  --master-user-password 'YOUR_SECURE_PASSWORD' \
  --allocated-storage 100 \
  --storage-type gp3 \
  --storage-encrypted \
  --backup-retention-period 7 \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name my-db-subnet-group \
  --publicly-accessible false

# Wait for availability
aws rds wait db-instance-available \
  --db-instance-identifier mmjc-production

# Get endpoint
AWS_DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier mmjc-production \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS Endpoint: $AWS_DB_ENDPOINT"

# Step 3: Initialize AWS database
psql -h $AWS_DB_ENDPOINT \
     -U admin \
     -d postgres \
     -c "CREATE DATABASE mmjc;"

# Step 4: Restore to AWS RDS
pg_restore -h $AWS_DB_ENDPOINT \
           -U admin \
           -d mmjc \
           --no-owner \
           --no-acl \
           -v \
           mmjc-database-backup-$(date +%Y%m%d).dump

# Step 5: Verify restoration
psql -h $AWS_DB_ENDPOINT \
     -U admin \
     -d mmjc \
     -c "\dt"  # List tables

psql -h $AWS_DB_ENDPOINT \
     -U admin \
     -d mmjc \
     -c "SELECT COUNT(*) FROM checkpoints;"

# Step 6: Run Airflow database migrations on AWS database
# (After restoring, ensure Airflow schema is up to date)
```

### 2.5 Database Connection Secrets for AWS

```yaml
# Update connection strings to point to AWS RDS
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret-test
  namespace: mmjc-test
type: Opaque
stringData:
  POSTGRESQL_USERNAME: "admin"  # or create specific user
  POSTGRESQL_PASSWORD: "YOUR_AWS_RDS_PASSWORD"

---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-postgres-connection-test
  namespace: airflow-test
type: Opaque
stringData:
  connection: "postgresql://admin:YOUR_AWS_RDS_PASSWORD@AWS_RDS_ENDPOINT:5432/mmjc?sslmode=require"
```

---

## 3. Object Storage Migration

### 3.1 IBM Cloud Object Storage → AWS S3

**Current IBM COS Configuration**:
- Endpoint: `https://s3.us-south.cloud-object-storage.appdomain.cloud`
- Used by:
  - Airflow (DAGs storage, logs)
  - Agents (file uploads, artifacts)
  - Frontend (static assets)

**Migration Steps**:

```bash
# Step 1: Create S3 buckets
aws s3 mb s3://mmjc-airflow-dags --region us-east-1
aws s3 mb s3://mmjc-airflow-logs --region us-east-1
aws s3 mb s3://mmjc-artifacts --region us-east-1
aws s3 mb s3://mmjc-uploads --region us-east-1

# Step 2: Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket mmjc-airflow-dags \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-versioning \
  --bucket mmjc-airflow-logs \
  --versioning-configuration Status=Enabled

# Step 3: Sync data from IBM COS to S3
# Install IBM Cloud CLI and COS plugin first
ibmcloud cos config list  # Get current COS config

# Option A: Using rclone (recommended for large migrations)
rclone sync ibmcos:your-bucket-name s3:mmjc-airflow-dags

# Option B: Manual sync via AWS CLI
# First download from IBM COS, then upload to S3
aws s3 sync /local/download/path s3://mmjc-airflow-dags/

# Step 4: Create AWS IAM user for S3 access
aws iam create-user --user-name mmjc-s3-user

aws iam attach-user-policy \
  --user-name mmjc-s3-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam create-access-key --user-name mmjc-s3-user

# Step 5: Update Kubernetes secrets
kubectl create secret generic s3-access-key-tools \
  -n mmjc-test \
  --from-literal=S3_ACCESS_KEY='AWS_ACCESS_KEY_ID' \
  --from-literal=S3_SECRET_KEY='AWS_SECRET_ACCESS_KEY' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 3.2 Update Application Configuration

```yaml
# agents deployment - update COS_ENDPOINT_URL
env:
  - name: COS_ENDPOINT_URL
    value: "https://s3.us-east-1.amazonaws.com"  # Change from IBM COS
  - name: COS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        key: S3_ACCESS_KEY
        name: s3-access-key-tools
  - name: COS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        key: S3_SECRET_KEY
        name: s3-secret-key-tools
```

---

## 4. Image Registry Migration

### 4.1 Current Image Sources

**IBM Cloud Container Registry** (`icr.io/mjc-cr`):
- mmjc-agents:0.0.2
- mmjc-frontend:0.0.2
- mmjc-po:0.0.2
- mmjc-airflow-service:3.0.2
- mcp-git-s3:1.0.31
- mcp-milvus-db:0.0.2
- mcp-context-forge:0.8.0
- mcp-arc-s3-server:2.1.45-amd64
- mjc-mermaid-validator:1.0.17-llm-ready-amd64

### 4.2 Options for AWS

**Option A**: Continue using IBM Cloud Container Registry (ICR)
- **Pros**: No migration needed, existing images work
- **Cons**: Cross-cloud egress costs, potential latency

**Option B**: Migrate to AWS ECR
- **Pros**: Lower latency, native AWS integration
- **Cons**: Requires image retagging and push

**Option C**: Hybrid approach
- Keep custom MMJC images in ICR
- Use public images (Milvus, Redis, etc.) from Docker Hub/Quay

**Recommended**: Option B (Full ECR migration)

```bash
# Step 1: Create ECR repositories
for repo in mmjc-agents mmjc-frontend mmjc-po mmjc-airflow-service \
            mcp-git-s3 mcp-milvus-db mcp-context-forge mcp-arc-s3-server \
            mjc-mermaid-validator; do
  aws ecr create-repository --repository-name $repo --region us-east-1
done

# Step 2: Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Step 3: Pull, tag, and push images
export AWS_ACCOUNT_ID="123456789012"  # Your AWS account ID
export AWS_REGION="us-east-1"

# Function to migrate image
migrate_image() {
  local source=$1
  local target=$2

  echo "Migrating: $source → $target"
  docker pull $source
  docker tag $source $target
  docker push $target
}

# Migrate all images
migrate_image "icr.io/mjc-cr/mmjc-agents:0.0.2" \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/mmjc-agents:0.0.2"

migrate_image "icr.io/mjc-cr/mmjc-frontend:0.0.2" \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/mmjc-frontend:0.0.2"

# ... repeat for all images

# Step 4: Update kustomization.yaml
# See Section 5.2 for kustomization updates
```

---

## 5. Kubernetes Resources Sync

### 5.1 Resource Export from IBM Cloud

```bash
# Export current cluster state
mkdir -p cluster-exports/{mmjc-test,airflow-test}

# Export mmjc-test namespace
kubectl get all,configmap,secret,pvc,ingress -n mmjc-test \
  -o yaml > cluster-exports/mmjc-test/all-resources.yaml

# Export airflow-test namespace
kubectl get all,configmap,secret,pvc,ingress -n airflow-test \
  -o yaml > cluster-exports/airflow-test/all-resources.yaml

# Export specific resource types separately for easier management
for ns in mmjc-test airflow-test; do
  kubectl get deployments -n $ns -o yaml > cluster-exports/$ns/deployments.yaml
  kubectl get statefulsets -n $ns -o yaml > cluster-exports/$ns/statefulsets.yaml
  kubectl get configmaps -n $ns -o yaml > cluster-exports/$ns/configmaps.yaml
  kubectl get services -n $ns -o yaml > cluster-exports/$ns/services.yaml
  kubectl get ingress -n $ns -o yaml > cluster-exports/$ns/ingress.yaml
  kubectl get pvc -n $ns -o yaml > cluster-exports/$ns/pvcs.yaml
done
```

### 5.2 Update Kustomize for AWS

**kustomize/mmjc-test/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mmjc-test

resources:
  # ... existing resources ...

# Update image registry to ECR
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mmjc-agents
    newTag: 0.0.2

  - name: icr.io/mjc-cr/mmjc-frontend
    newName: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mmjc-frontend
    newTag: 0.0.2

  # ... update all custom images ...

# Add AWS-specific labels
commonLabels:
  environment: production
  cloud-provider: aws
  managed-by: kustomize
```

**kustomize/airflow-test/kustomization.yaml**:
```yaml
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mmjc-airflow-service
    newTag: "3.0.2"  # Already fixed from 'latest'
```

### 5.3 Create AWS Overlay

```bash
mkdir -p kustomize/overlays/aws
```

**kustomize/overlays/aws/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../mmjc-test
  - ../../airflow-test

namespace: production  # Or keep mmjc-test/airflow-test

# AWS-specific patches
patchesStrategicMerge:
  - patches/aws-storage-class.yaml
  - patches/aws-load-balancer.yaml
  - patches/aws-iam-roles.yaml

# AWS-specific ConfigMap overrides
configMapGenerator:
  - name: aws-region-config
    literals:
      - AWS_REGION=us-east-1
      - AWS_DEFAULT_REGION=us-east-1

# Image registry transformation to ECR
images:
  - name: icr.io/mjc-cr/mmjc-agents
    newName: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/mmjc-agents

  # ... all other images ...

commonLabels:
  environment: production
  cloud: aws
  region: us-east-1
```

### 5.4 Deploy to AWS EKS

```bash
# Step 1: Switch to AWS EKS context
kubectl config use-context your-eks-cluster

# Step 2: Create namespaces
kubectl create namespace mmjc-test
kubectl create namespace airflow-test

# Step 3: Apply secrets (updated with AWS values)
kubectl apply -f kustomize/mmjc-test/secrets/
kubectl apply -f kustomize/airflow-test/secrets/

# Step 4: Test kustomize build
kubectl kustomize kustomize/overlays/aws > /tmp/aws-deployment.yaml

# Review before applying
less /tmp/aws-deployment.yaml

# Step 5: Apply in order
# First: ConfigMaps and Secrets
kubectl apply -k kustomize/overlays/aws --selector=component=config

# Second: StatefulSets and PVCs
kubectl apply -k kustomize/overlays/aws --selector=component=storage

# Third: Deployments and Services
kubectl apply -k kustomize/overlays/aws

# Step 6: Monitor rollout
kubectl rollout status deployment/agents-mmjc-test -n mmjc-test
kubectl rollout status deployment/airflow-test-scheduler -n airflow-test

# Step 7: Verify pods
kubectl get pods -n mmjc-test
kubectl get pods -n airflow-test
```

---

## 6. Configuration Updates

### 6.1 Environment Variables to Update

**Agents Deployment**:
```yaml
env:
  # Database - AWS RDS
  - name: POSTGRESQL_HOST
    value: "mmjc-production.xxxxx.us-east-1.rds.amazonaws.com"
  - name: POSTGRESQL_PORT
    value: "5432"  # Default PostgreSQL port

  # Object Storage - S3
  - name: COS_ENDPOINT_URL
    value: "https://s3.us-east-1.amazonaws.com"

  # LLM Gateway - May need update if IBM-specific
  - name: OPENAI_API_BASE
    value: "https://your-aws-llm-gateway.example.com/v1"
```

**Airflow Configuration**:
```yaml
# airflow-config ConfigMap
data:
  airflow.cfg: |
    [core]
    sql_alchemy_conn = postgresql://admin:PASSWORD@RDS_ENDPOINT:5432/mmjc

    [celery]
    broker_url = redis://redis-cluster-test.mmjc-test.svc.cluster.local:6379/0

    [logging]
    remote_logging = True
    remote_base_log_folder = s3://mmjc-airflow-logs
    remote_log_conn_id = aws_default
```

### 6.2 External Dependencies

**Update DNS/URLs**:
- [ ] LLM Gateway URL (if migrating)
- [ ] GitHub webhook URLs
- [ ] External API endpoints
- [ ] OAuth callback URLs

---

## 7. Network and DNS

### 7.1 Ingress Configuration

```yaml
# AWS Application Load Balancer
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mmjc-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
spec:
  rules:
    - host: agents.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: agents-mmjc-test
                port:
                  number: 8080
```

### 7.2 DNS Migration

```bash
# Route53 setup
aws route53 create-hosted-zone \
  --name mmjc.example.com \
  --caller-reference $(date +%s)

# Get Load Balancer DNS
ALB_DNS=$(kubectl get ingress mmjc-ingress -n mmjc-test \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create CNAME record
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "agents.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$ALB_DNS'"}]
      }
    }]
  }'
```

---

## 8. Testing and Validation

### 8.1 Smoke Tests

```bash
# Test database connectivity
kubectl run -it --rm psql-test \
  --image=postgres:16.8 \
  --env="PGPASSWORD=PASSWORD" \
  -- psql -h RDS_ENDPOINT -U admin -d mmjc -c "SELECT 1;"

# Test Redis
kubectl run -it --rm redis-test \
  --image=redis:8.0.2 \
  -- redis-cli -h redis-cluster-test.mmjc-test.svc.cluster.local ping

# Test S3 access
kubectl run -it --rm aws-cli-test \
  --image=amazon/aws-cli \
  -- s3 ls s3://mmjc-artifacts/

# Test agents API
kubectl port-forward -n mmjc-test svc/agents-mmjc-test 8080:8080 &
curl http://localhost:8080/health

# Test Airflow
kubectl port-forward -n airflow-test svc/airflow-test-webserver 8080:8080 &
curl http://localhost:8080/health
```

### 8.2 Functional Tests

- [ ] Create test Airflow DAG and verify execution
- [ ] Test agent conversation with checkpoint persistence
- [ ] Verify Milvus vector search
- [ ] Test file upload to S3
- [ ] Verify Mermaid diagram validation
- [ ] Test MCP gateway connectivity

### 8.3 Performance Validation

```bash
# Compare response times
# IBM Cloud baseline
kubectl top pods -n mmjc-test

# AWS EKS after migration
kubectl top pods -n mmjc-test

# Run load tests
# Use your existing load testing tools
```

---

## 9. Rollback Plan

### 9.1 Rollback Triggers

- Database connectivity failures
- >10% increase in error rates
- Critical feature failures
- Performance degradation >20%

### 9.2 Rollback Procedure

```bash
# Step 1: Switch DNS back to IBM Cloud
aws route53 change-resource-record-sets ...

# Step 2: Revert database connection strings
kubectl patch secret postgresql-secret-test -n mmjc-test ...

# Step 3: Scale down AWS deployments
kubectl scale deployment --all --replicas=0 -n mmjc-test
kubectl scale deployment --all --replicas=0 -n airflow-test

# Step 4: Restore IBM Cloud pods if needed
kubectl config use-context ibm-cloud-context
kubectl scale deployment agents-mmjc-test --replicas=4 -n mmjc-test

# Step 5: Notify team and document issues
```

---

## 10. Post-Migration Tasks

### 10.1 Cleanup

```bash
# After successful migration and validation period:

# Deprovision IBM Cloud resources
ibmcloud ks cluster rm --cluster mjc-cluster

# Cancel IBM Cloud Database
ibmcloud resource service-instance-delete postgresql-instance

# Remove IBM Cloud Object Storage buckets (after final backup)
ibmcloud cos bucket-delete --bucket your-bucket-name

# Remove ICR repositories (optional, keep for rollback)
# ibmcloud cr image-rm icr.io/mjc-cr/mmjc-agents:0.0.2
```

### 10.2 Documentation Updates

- [ ] Update deployment documentation
- [ ] Update runbooks with new endpoints
- [ ] Document new AWS resource ARNs
- [ ] Update disaster recovery procedures
- [ ] Create AWS cost monitoring dashboards

### 10.3 Monitoring and Alerting

```bash
# Setup CloudWatch dashboards
aws cloudwatch put-dashboard ...

# Configure alarms
aws cloudwatch put-metric-alarm \
  --alarm-name mmjc-high-cpu \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --period 300 \
  --statistic Average \
  --threshold 80
```

---

## Migration Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| **Week 1** | 5 days | Environment setup, RDS provisioning, ECR setup |
| **Week 2** | 5 days | Database migration, testing, schema validation |
| **Week 3** | 5 days | Image migration to ECR, S3 sync |
| **Week 4** | 5 days | Kubernetes deployment, integration testing |
| **Week 5** | 5 days | Performance testing, bug fixes |
| **Week 6** | 2 days | Go-live, monitoring, hypercare |

**Total**: ~30 days (6 weeks)

---

## Critical Path Items

1. ✅ Fix Airflow `postgres://` → `postgresql://` scheme
2. ✅ Create `checkpoints` table (run init-database.yaml job)
3. ⏳ Provision AWS RDS PostgreSQL 16.8
4. ⏳ Migrate database with pg_dump/restore
5. ⏳ Setup ECR and migrate images
6. ⏳ Configure S3 and sync data
7. ⏳ Deploy to EKS and validate
8. ⏳ DNS cutover

---

## Contact and Escalation

**Migration Team**:
- Database Admin: [Name]
- Platform Engineer: [Name]
- DevOps Lead: [Name]
- Application Owner: [Name]

**Escalation Matrix**:
- L1: Platform Engineer (response: 1h)
- L2: DevOps Lead (response: 30m)
- L3: CTO (response: immediate)

---

## Appendices

### A. Useful Commands Reference

```bash
# Quick context switch
alias k8s-ibm="kubectl config use-context ibm-cloud"
alias k8s-aws="kubectl config use-context aws-eks"

# Port forwarding
alias pf-airflow="kubectl port-forward -n airflow-test svc/airflow-test-webserver 8080:8080"
alias pf-agents="kubectl port-forward -n mmjc-test svc/agents-mmjc-test 8080:8080"

# Log tailing
alias logs-agents="kubectl logs -n mmjc-test -l app=agents-mmjc --tail=100 -f"
alias logs-airflow="kubectl logs -n airflow-test -l component=scheduler --tail=100 -f"
```

### B. Secret Templates

See `kustomize/mmjc-test/secrets/secrets-template.json` and
`kustomize/airflow-test/secrets/airflow-test-secrets-template.yaml`

### C. Database Schema Files

- `database/schemas/langgraph-checkpoints.sql` - LangGraph checkpoints table
- `database/init-mmjc-database.sql` - Full database initialization

---

**Document Version**: 1.0
**Last Updated**: 2025-11-02
**Status**: Draft - Pending Review
