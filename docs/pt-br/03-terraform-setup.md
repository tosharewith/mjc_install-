# Setup da Infraestrutura AWS com Terraform

Este documento detalha como criar a infraestrutura AWS necessária usando Terraform.

## Visão Geral

O Terraform criará os seguintes recursos:
- Amazon RDS PostgreSQL 15 (metadata do Airflow)
- Redis as Cache (Redis 7 - message broker do Airflow)
- Amazon S3 Buckets (logs, DAGs, dados do Milvus)
- Kubernetes Namespaces no EKS
- Security Groups e regras de rede

## Estrutura dos Arquivos Terraform

```
terraform/
├── modules/
│   ├── vpc/           # VPC e networking (opcional)
│   ├── rds/           # RDS PostgreSQL
│   ├── elasticache/   # Redis as Cache
│   └── s3/            # S3 Buckets
└── environments/
    └── dev/
        ├── main.tf           # Configuração principal
        ├── variables.tf      # Variáveis
        ├── terraform.tfvars  # Valores das variáveis
        └── outputs.tf        # Outputs
```

## Pré-requisitos

### 1. Backend do Terraform (State Storage)

O state do Terraform será armazenado no S3:

```bash
# Criar bucket para state (executar uma vez)
aws s3 mb s3://itau-terraform-state-dev --region us-east-1

# Criar tabela DynamoDB para lock
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Cluster EKS

Este Terraform assume que o cluster EKS já existe. Se não existe, crie antes:

```bash
# Verificar se cluster existe
aws eks describe-cluster --name SEU_CLUSTER_EKS --region us-east-1

# Se não existe, criar (exemplo básico)
eksctl create cluster \
  --name SEU_CLUSTER_EKS \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.xlarge \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5
```

## Configuração

### 1. Copiar Arquivo de Variáveis

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

### 2. Editar terraform.tfvars

```hcl
# terraform/environments/dev/terraform.tfvars

# AWS Configuration
aws_region = "us-east-1"

# EKS Cluster
eks_cluster_name = "seu-cluster-eks"

# Project
project_name = "itau-airflow-milvus"
environment  = "dev"

# VPC (se criar nova VPC)
create_new_vpc     = false
existing_vpc_id    = "vpc-xxxxx"
existing_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

# Ou criar nova VPC
# create_new_vpc = true
# vpc_cidr = "10.0.0.0/16"
# availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# RDS PostgreSQL
rds_instance_class    = "db.t3.medium"
rds_allocated_storage = 100
db_username           = "airflow_admin"
# db_password será solicitado no apply ou usar AWS Secrets Manager

# Redis as Cache
redis_node_type = "cache.t3.medium"

# Tags
tags = {
  Environment = "dev"
  Project     = "airflow-milvus-migration"
  Team        = "data-platform"
}
```

### 3. Configurar Credenciais AWS

```bash
# Configurar AWS CLI
aws configure

# Ou usar perfil específico
export AWS_PROFILE=seu-perfil

# Validar
aws sts get-caller-identity
```

## Executar Terraform

### 1. Inicializar Terraform

```bash
cd terraform/environments/dev

# Inicializar (baixa providers e módulos)
terraform init
```

### 2. Planejar Mudanças

```bash
# Ver o que será criado
terraform plan

# Salvar plano (recomendado)
terraform plan -out=tfplan
```

Revise o output cuidadosamente. Deve mostrar:
- 1 RDS instance
- 1 Redis as Cache cluster
- 3 S3 buckets
- 2 Kubernetes namespaces
- Security groups e regras

### 3. Aplicar Mudanças

```bash
# Aplicar com plano salvo
terraform apply tfplan

# Ou aplicar diretamente (solicitará confirmação)
terraform apply
```

**Tempo estimado**: 10-15 minutos

### 4. Verificar Outputs

Após o apply, o Terraform mostrará outputs importantes:

```bash
# Ver outputs
terraform output

# Outputs esperados:
# rds_endpoint = "itau-airflow-postgres.xxxxx.us-east-1.rds.amazonaws.com:5432"
# redis_endpoint = "itau-airflow-redis.xxxxx.cache.amazonaws.com:6379"
# s3_buckets = {
#   logs   = "itau-airflow-milvus-airflow-logs"
#   dags   = "itau-airflow-milvus-airflow-dags"
#   milvus = "itau-airflow-milvus-milvus-data"
# }
```

Salve estes valores, serão necessários para configurar o Airflow.

## Recursos Criados

### 1. RDS PostgreSQL

```
Instance: itau-airflow-milvus-airflow-postgres
Engine: PostgreSQL 15.4
Class: db.t3.medium
Storage: 100GB gp3
Multi-AZ: Não (dev) / Sim (prod)
Backup: 7 dias
Encryption: Sim
```

**Connection String**:
```
postgresql://airflow_admin:PASSWORD@ENDPOINT:5432/airflow
```

### 2. Redis as Cache

```
Cluster: itau-airflow-milvus-airflow-redis
Engine: Redis 7.x
Node Type: cache.t3.medium
Nodes: 1 (dev) / 2+ (prod)
Encryption: Sim (in-transit e at-rest)
```

**Connection String**:
```
redis://ENDPOINT:6379
```

### 3. S3 Buckets

```
itau-airflow-milvus-airflow-logs
├── Versioning: Enabled
├── Lifecycle: 90 dias
└── Encryption: AES-256

itau-airflow-milvus-airflow-dags
├── Versioning: Enabled
├── Lifecycle: Disabled
└── Encryption: AES-256

itau-airflow-milvus-milvus-data
├── Versioning: Enabled
├── Lifecycle: Disabled
└── Encryption: AES-256
```

### 4. Kubernetes Namespaces

```bash
# Verificar namespaces criados
kubectl get namespaces

# Outputs esperados:
# airflow-test   Active   5m
# milvus-dev     Active   5m
```

## Validação

### 1. Validar RDS

```bash
# Obter endpoint
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Testar conexão (de dentro do cluster)
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql -h $RDS_ENDPOINT -U airflow_admin -d airflow -c "SELECT version();"
```

### 2. Validar Redis

```bash
# Obter endpoint
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)

# Testar conexão
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -- \
  redis-cli -h $REDIS_ENDPOINT ping
```

### 3. Validar S3

```bash
# Listar buckets criados
aws s3 ls | grep airflow

# Testar escrita
echo "test" | aws s3 cp - s3://itau-airflow-milvus-airflow-logs/test.txt

# Testar leitura
aws s3 cp s3://itau-airflow-milvus-airflow-logs/test.txt -
```

## Troubleshooting

### Erro: Cluster EKS não encontrado

```
Error: reading EKS Cluster (seu-cluster): couldn't find resource
```

**Solução**:
```bash
# Verificar nome do cluster
aws eks list-clusters --region us-east-1

# Atualizar terraform.tfvars com nome correto
```

### Erro: Subnets inválidas

```
Error: Error creating DB Subnet Group: InvalidSubnet
```

**Solução**:
- Verificar que as subnets estão em AZs diferentes
- Verificar que as subnets são privadas
- Atualizar `existing_subnet_ids` em terraform.tfvars

### Erro: Security Group não permite acesso

```
Error: timeout connecting to RDS
```

**Solução**:
```bash
# Verificar security groups
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region us-east-1

# Adicionar regra manualmente se necessário
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 5432 \
  --source-group sg-yyyyy
```

## Limpeza (Destruir Recursos)

**ATENÇÃO**: Isso deletará todos os recursos criados!

```bash
# Ver o que será destruído
terraform plan -destroy

# Destruir (solicita confirmação)
terraform destroy

# Ou forçar sem confirmação
terraform destroy -auto-approve
```

## Custos Estimados

Estimativa mensal (região us-east-1):

| Recurso | Tipo | Custo Mensal (USD) |
|---------|------|---------------------|
| RDS PostgreSQL | db.t3.medium | ~$60 |
| Redis as Cache | cache.t3.medium | ~$50 |
| S3 (100GB) | Standard | ~$3 |
| EBS Snapshots (backup RDS) | 100GB | ~$5 |
| **Total** | | **~$118/mês** |

## Próximos Passos

Após criar a infraestrutura AWS, prossiga para:
1. [04-airflow-migration.md](04-airflow-migration.md) - Migrar o Airflow
2. [05-milvus-migration.md](05-milvus-migration.md) - Migrar o Milvus
