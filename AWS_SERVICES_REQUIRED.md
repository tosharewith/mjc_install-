# 🔧 Serviços AWS Necessários

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Serviços Core](#serviços-core)
3. [Serviços de Rede](#serviços-de-rede)
4. [Serviços de Armazenamento](#serviços-de-armazenamento)
5. [Serviços de Segurança](#serviços-de-segurança)
6. [Serviços Opcionais](#serviços-opcionais)
7. [Configuração Manual vs Terraform](#configuração-manual-vs-terraform)

## ✅ Pré-requisitos

### 1. Cluster EKS Existente ⚠️ **OBRIGATÓRIO**

**Status**: Deve existir previamente

```bash
# Verificar se existe
aws eks describe-cluster --name SEU_CLUSTER --region us-east-1
```

**Requisitos do Cluster**:
- ✅ Kubernetes versão >= 1.27
- ✅ Security groups configurados
- ✅ IAM OIDC Provider habilitado (para IRSA)
- ✅ VPC com subnets públicas e privadas
- ✅ Nodes funcionando

**Se não existir**: Cluster EKS precisa ser criado separadamente antes de executar esta migração.

### 2. Conta AWS

- ✅ AWS Account ID
- ✅ Credenciais (AWS Access Key ID + Secret ou IAM Role)
- ✅ Região escolhida (ex: us-east-1)

## 🎯 Serviços Core

### 1. ⭐ Amazon RDS (PostgreSQL) - **OBRIGATÓRIO**

**Para**: Banco de dados do Airflow

**Configuração**:
```yaml
Engine: PostgreSQL 15.4
Instance Class: db.t3.medium (ajustável)
Storage: 100GB (ajustável)
Multi-AZ: Sim (recomendado)
Backup: Automático (7 dias)
Encryption: At rest (obrigatório)
```

**Criado por**: Terraform (`module "rds_postgres"`)

**Alternativa**: Pode usar RDS existente se já tiver

**Validação**:
```bash
aws rds describe-db-instances \
    --db-instance-identifier itau-airflow-postgres
```

---

### 2. ⭐ Redis as Cache - **OBRIGATÓRIO**

**Para**: Message broker do Airflow (Celery)

**Configuração**:
```yaml
Engine: Redis 7.x
Node Type: cache.t3.medium (ajustável)
Number of Nodes: 1 (pode escalar)
Encryption: In-transit (recomendado)
```

**Criado por**: Terraform (`module "redis_cache"`)

**Alternativa**: Pode usar cluster Redis existente

**Validação**:
```bash
aws elasticache describe-cache-clusters \
    --cache-cluster-id itau-airflow-redis
```

---

### 3. ⭐ Amazon S3 - **OBRIGATÓRIO**

**Para**:
- Logs do Airflow
- DAGs do Airflow
- Dados do Milvus (opcional, substitui MinIO interno)
- Terraform State (backend)

**Buckets Criados**:

| Bucket | Propósito | Versioning | Lifecycle |
|--------|-----------|------------|-----------|
| `{project}-airflow-logs` | Logs do Airflow | ✅ Sim | 90 dias |
| `{project}-airflow-dags` | Código DAGs | ✅ Sim | Sem expiração |
| `{project}-milvus-data` | Dados Milvus | ✅ Sim | Sem expiração |
| `itau-terraform-state-dev` | State do Terraform | ✅ Sim | Sem expiração |

**Criado por**: Terraform (`module "s3_buckets"`)

**Configuração**:
```yaml
Encryption: AES-256 (SSE-S3)
Public Access: Blocked
Versioning: Enabled
Lifecycle Rules: Configurado por bucket
```

**Validação**:
```bash
aws s3 ls
aws s3api get-bucket-versioning --bucket itau-airflow-logs
```

**⚠️ Bucket para Terraform State**:
```bash
# Criar manualmente ANTES de executar terraform
aws s3api create-bucket \
    --bucket itau-terraform-state-dev \
    --region us-east-1

aws s3api put-bucket-versioning \
    --bucket itau-terraform-state-dev \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
    --bucket itau-terraform-state-dev \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
```

---

### 4. ⭐ Amazon DynamoDB - **RECOMENDADO**

**Para**: Lock do Terraform State

**Configuração**:
```yaml
Table Name: terraform-lock
Primary Key: LockID (String)
Billing Mode: PAY_PER_REQUEST
```

**Criação Manual**:
```bash
aws dynamodb create-table \
    --table-name terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

**Validação**:
```bash
aws dynamodb describe-table --table-name terraform-lock
```

## 🌐 Serviços de Rede

### 5. Amazon VPC - **CONDICIONAL**

**Status**: Pode usar VPC existente do EKS OU criar nova

**Se criar nova**:
```yaml
CIDR: 10.0.0.0/16 (ajustável)
Subnets Públicas: 3 (uma por AZ)
Subnets Privadas: 3 (uma por AZ)
NAT Gateways: 3 (alta disponibilidade) ou 1 (economia)
Internet Gateway: 1
```

**Criado por**: Terraform (`module "vpc"`) - apenas se `CREATE_NEW_VPC=true`

**Se usar VPC existente**:
```bash
# Identificar VPC do EKS
aws eks describe-cluster --name SEU_CLUSTER \
    --query 'cluster.resourcesVpcConfig.vpcId'
```

---

### 6. ⭐ AWS Application Load Balancer (ALB) - **OBRIGATÓRIO**

**Para**: Ingress do Kubernetes (expor Airflow e outros serviços)

**Configuração**:
```yaml
Scheme: internet-facing
Target Type: IP (para EKS)
SSL/TLS: ACM Certificate
```

**Criado por**: AWS Load Balancer Controller (Kubernetes Ingress)

**Pré-requisito**: AWS Load Balancer Controller instalado no EKS

**Instalação do Controller** (se não existir):
```bash
# 1. Criar IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# 2. Instalar via Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=SEU_CLUSTER \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller
```

**Validação**:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

### 7. Amazon EBS - **AUTOMÁTICO**

**Para**: Persistent Volumes do Kubernetes

**Configuração**:
```yaml
Storage Class: gp3 (General Purpose SSD)
Volumes criados automaticamente via PVCs
```

**Criado por**: EBS CSI Driver (deve estar instalado no EKS)

**Validação**:
```bash
kubectl get storageclass
# Deve mostrar 'gp3' ou 'gp2'
```

## 🔐 Serviços de Segurança

### 8. ⭐ AWS IAM - **OBRIGATÓRIO**

**Para**: Permissões e acessos

**Recursos Criados**:

#### a) IAM Roles
- Role para acesso S3 (IRSA - IAM Roles for Service Accounts)
- Role para RDS (se necessário)
- Role para Redis as Cache (se necessário)

#### b) IAM Policies
- Política de acesso S3 (read/write)
- Política de acesso RDS (connect)
- Política least privilege

**Criado por**: Terraform (módulos de cada serviço)

**Validação**:
```bash
aws iam list-roles | grep airflow
aws iam list-policies --scope Local | grep airflow
```

---

### 9. AWS Certificate Manager (ACM) - **RECOMENDADO**

**Para**: Certificados SSL/TLS para ALB

**Configuração**:
```yaml
Domain: *.seu-dominio.com
Validation: DNS ou Email
```

**Criação**:
```bash
aws acm request-certificate \
    --domain-name "*.seu-dominio.com" \
    --subject-alternative-names "seu-dominio.com" \
    --validation-method DNS \
    --region us-east-1
```

**Validação**:
```bash
aws acm list-certificates --region us-east-1
```

**Usado em**: Ingress annotations

---

### 10. AWS Secrets Manager - **OPCIONAL**

**Para**: Gestão centralizada de secrets (alternativa ao Kubernetes Secrets)

**Uso**: Se quiser integrar com External Secrets Operator

**Não criado por padrão** - Usar Kubernetes Secrets nativos

## 🔌 Serviços Opcionais

### 11. Amazon ECR (Elastic Container Registry) - **OPCIONAL**

**Para**: Hospedar imagens de container

**Alternativa**: Pode usar IBM ICR da conta Itaú

**Se usar ECR**:
```bash
# Criar repositórios
aws ecr create-repository --repository-name mmjc-airflow-service
aws ecr create-repository --repository-name statsd-exporter

# Ver repositórios
aws ecr describe-repositories
```

---

### 12. Amazon CloudWatch - **RECOMENDADO**

**Para**: Logs e métricas

**Uso**:
- Logs dos pods (via Fluent Bit)
- Métricas do cluster
- Alarmes

**Configuração**:
```bash
# Instalar CloudWatch Container Insights
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html
```

---

### 13. Amazon Route 53 - **OPCIONAL**

**Para**: DNS management

**Uso**: Apontar domínio para ALB

**Alternativa**: Pode usar DNS provider existente

## 📊 Resumo: Obrigatório vs Opcional

### ⚠️ OBRIGATÓRIO (Devem Existir/Ser Criados)

| Serviço | Quem Cria | Quando |
|---------|-----------|--------|
| ✅ **EKS Cluster** | Manual (pré-existente) | Antes de tudo |
| ✅ **RDS PostgreSQL** | Terraform | Durante migração |
| ✅ **Redis as Cache** | Terraform | Durante migração |
| ✅ **S3 Buckets** | Terraform + Manual (state) | Antes/Durante migração |
| ✅ **IAM Roles/Policies** | Terraform | Durante migração |
| ✅ **ALB Controller** | Manual (Helm) | Antes da migração |

### ⚙️ CONDICIONAL (Depende da Configuração)

| Serviço | Quando Necessário |
|---------|-------------------|
| **VPC** | Se não usar VPC existente do EKS |
| **DynamoDB** | Recomendado para Terraform lock |
| **ACM** | Se usar HTTPS (recomendado) |

### 💡 OPCIONAL (Melhorias)

| Serviço | Benefício |
|---------|-----------|
| **ECR** | Hospedar imagens (alternativa: IBM ICR) |
| **CloudWatch** | Monitoramento avançado |
| **Route 53** | Gestão de DNS |
| **Secrets Manager** | Gestão centralizada de secrets |

## 🚀 Ordem de Configuração

### Passo 1: Pré-requisitos (Manual)

```bash
# 1.1. Verificar EKS existe
aws eks describe-cluster --name SEU_CLUSTER

# 1.2. Criar bucket para Terraform state
aws s3api create-bucket --bucket itau-terraform-state-dev --region us-east-1
aws s3api put-bucket-versioning --bucket itau-terraform-state-dev \
    --versioning-configuration Status=Enabled

# 1.3. Criar tabela DynamoDB para lock
aws dynamodb create-table \
    --table-name terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# 1.4. Instalar AWS Load Balancer Controller (se não existir)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system --set clusterName=SEU_CLUSTER
```

### Passo 2: Terraform Cria Automaticamente

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

**Cria**:
- ✅ RDS PostgreSQL
- ✅ Redis as Cache
- ✅ S3 Buckets (aplicação)
- ✅ IAM Roles/Policies
- ✅ Security Groups
- ✅ VPC (se configurado)

### Passo 3: Kubernetes Cria Dinamicamente

```bash
kubectl apply -k kustomize/airflow-test/
```

**Cria**:
- ✅ ALB (via Ingress)
- ✅ EBS Volumes (via PVCs)
- ✅ Namespaces
- ✅ Secrets
- ✅ ConfigMaps

## 📝 Checklist de Configuração

### Antes de Iniciar

- [ ] Cluster EKS existe e está acessível
- [ ] AWS CLI configurado com credenciais
- [ ] kubectl configurado para o cluster
- [ ] Terraform instalado
- [ ] Helm instalado

### Serviços AWS a Criar/Verificar

- [ ] S3 bucket para Terraform state (`itau-terraform-state-dev`)
- [ ] DynamoDB table para lock (`terraform-lock`)
- [ ] AWS Load Balancer Controller instalado no EKS
- [ ] EBS CSI Driver instalado no EKS (geralmente já vem)
- [ ] ACM Certificate (se usar HTTPS)
- [ ] IAM OIDC Provider habilitado no EKS (para IRSA)

### Durante Terraform Apply

- [ ] RDS PostgreSQL criado
- [ ] Redis as Cache criado
- [ ] S3 buckets da aplicação criados
- [ ] IAM Roles criados
- [ ] Security Groups criados
- [ ] VPC criada (se aplicável)

### Após Deploy Kubernetes

- [ ] ALB provisionado (pode levar 2-3 minutos)
- [ ] EBS volumes bound
- [ ] Pods running
- [ ] Services acessíveis

## 🔍 Comandos de Validação

```bash
# Verificar todos serviços de uma vez
cat > validate-aws-services.sh << 'EOF'
#!/bin/bash
echo "🔍 Validando Serviços AWS..."
echo ""

echo "1. EKS Cluster:"
aws eks describe-cluster --name $EKS_CLUSTER_NAME --query 'cluster.status' || echo "❌ EKS não encontrado"

echo "2. RDS:"
aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `airflow`)].DBInstanceStatus' || echo "❌ RDS não encontrado"

echo "3. Redis as Cache:"
aws elasticache describe-cache-clusters --query 'CacheClusters[?contains(CacheClusterId, `airflow`)].CacheClusterStatus' || echo "❌ Redis não encontrado"

echo "4. S3 Buckets:"
aws s3 ls | grep airflow || echo "❌ Buckets não encontrados"

echo "5. DynamoDB:"
aws dynamodb describe-table --table-name terraform-lock --query 'Table.TableStatus' || echo "❌ DynamoDB table não encontrada"

echo "6. ALB Controller:"
kubectl get deployment -n kube-system aws-load-balancer-controller || echo "❌ ALB Controller não instalado"

echo ""
echo "✅ Validação concluída"
EOF

chmod +x validate-aws-services.sh
./validate-aws-services.sh
```

## 💡 Monitoramento de Recursos

**Configure alertas e monitoramento para**:
- EKS Cluster (control plane + nodes)
- RDS PostgreSQL (instância + storage + backup)
- Redis as Cache (nodes)
- S3 (storage + requests)
- EBS Volumes (storage)
- ALB (data processed)
- NAT Gateways (se usar)
- Data Transfer (entre AZs e internet)

**Ferramentas**: Configure AWS Budgets, Cost Explorer e CloudWatch Alarms

---

**Última atualização**: 2025-10-29
**Documentação complementar**: README.md, QUICKSTART.md, DEPLOYMENT.md
