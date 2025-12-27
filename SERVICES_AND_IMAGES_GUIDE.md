# 🔍 Guia Completo: Serviços e Imagens para Migração

**Data**: 2025-12-27
**Fonte**: Namespace mmjc-test
**Objetivo**: Identificar serviços internos vs AWS, imagens para migração e configuração GenAI

---

## 📦 1. IMAGENS DOCKER PARA MIGRAÇÃO

### 1.1 Imagens Identificadas (mmjc-test namespace)

#### MMJC Custom Applications

| Imagem Original | Componente | Versão | Prioridade |
|----------------|------------|--------|------------|
| `icr.io/mjc-cr/mmjc-agents` | Agents Service | `0.0.2` | 🔴 ALTA |
| `icr.io/mjc-cr/mmjc-frontend` | Frontend | `0.0.2` | 🔴 ALTA |
| `icr.io/mjc-cr/mmjc-po` | Process Orchestrator | `0.0.2` | 🔴 ALTA |
| `icr.io/mjc-cr/mojoco-entities-manager` | Entities Manager | `0.0.2` | 🔴 ALTA |
| `icr.io/mjc-cr/mjc-mermaid-validator` | Mermaid Validator | `1.0.17-llm-ready-amd64` | 🔴 ALTA |

#### MCP Servers

| Imagem Original | Componente | Versão | Prioridade |
|----------------|------------|--------|------------|
| `icr.io/mjc-cr/go-mcp-git-s3` | Git-S3 Server | `1.0.31` | 🔴 ALTA |
| `icr.io/mjc-cr/arc-spring-api` | ARC S3 Server | `3.1.2-amd64` | 🔴 ALTA |
| `icr.io/mjc-cr/mcp-context-forge` | Context Forge (Gateway) | `0.9.0` | 🔴 ALTA |
| `icr.io/mjc-cr/mcp-milvus-db` | Milvus DB Server | `0.0.2` | 🔴 ALTA |

#### Infrastructure

| Imagem Original | Componente | Versão | Prioridade |
|----------------|------------|--------|------------|
| `milvusdb/milvus` | Milvus (5 componentes) | `v2.5.15` | 🔴 ALTA |
| `docker.io/milvusdb/etcd` | Etcd | `3.5.18-r1` | 🔴 ALTA |
| `docker.io/bitnami/kafka` | Kafka | `3.1.0-debian-10-r52` | 🔴 ALTA |
| `docker.io/bitnami/zookeeper` | Zookeeper | `3.7.0-debian-10-r320` | 🔴 ALTA |
| `minio/minio` | MinIO | `RELEASE.2024-05-28T17-19-04Z` | 🔴 ALTA |
| `redis` | Redis | `8.0.2` | 🔴 ALTA |
| `zilliz/attu` | Attu (Milvus UI) | `v2.5.6` | 🟡 MÉDIA |

**Total estimado**: ~8-10GB de imagens

### 1.2 Imagens que DEVEM ser Migradas

**MMJC Custom Applications** (IBM Container Registry - privado):
```bash
icr.io/mjc-cr/mmjc-agents:0.0.2
icr.io/mjc-cr/mmjc-frontend:0.0.2
icr.io/mjc-cr/mmjc-po:0.0.2
icr.io/mjc-cr/mojoco-entities-manager:0.0.2
icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64
```

**MCP Servers** (IBM Container Registry - privado):
```bash
icr.io/mjc-cr/go-mcp-git-s3:1.0.31
icr.io/mjc-cr/arc-spring-api:3.1.2-amd64
icr.io/mjc-cr/mcp-context-forge:0.9.0
icr.io/mjc-cr/mcp-milvus-db:0.0.2
```

**Infrastructure** (public registries):
```bash
milvusdb/milvus:v2.5.15
docker.io/milvusdb/etcd:3.5.18-r1
docker.io/bitnami/kafka:3.1.0-debian-10-r52
docker.io/bitnami/zookeeper:3.7.0-debian-10-r320
minio/minio:RELEASE.2024-05-28T17-19-04Z
redis:8.0.2
zilliz/attu:v2.5.6
```

### 1.3 Opções de Migração de Imagens

#### Opção A: Migrar para AWS ECR (Recomendado para AWS)

```bash
# 1. Login no ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# 2. Criar repositórios
aws ecr create-repository --repository-name milvus
aws ecr create-repository --repository-name etcd
aws ecr create-repository --repository-name kafka
aws ecr create-repository --repository-name zookeeper
aws ecr create-repository --repository-name mmjc-airflow-service

# 3. Migrar imagens (usar script automatizado)
./scripts/migrate-container-images.sh
```

#### Opção B: Migrar para IBM ICR (conta Itaú)

```bash
# 1. Login na conta Itaú
~/ibm-login-itau

# 2. Criar namespace
ibmcloud cr namespace-add itau-airflow

# 3. Configurar registry
export TARGET_REGISTRY=icr.io/itau-airflow

# 4. Migrar
./scripts/migrate-container-images.sh
```

#### Opção C: Usar Registries Originais (Temporário - NÃO RECOMENDADO)

```bash
# Apenas para testes rápidos
# Requer acesso ao icr.io/mjc-cr (IBM Cloud original)
```

---

## 🏗️ 2. SERVIÇOS: INTERNO vs AWS

### 2.1 Serviços INTERNOS ao Cluster (Não precisam AWS)

Estes rodam completamente dentro do Kubernetes:

| Serviço | Namespace | Pods | Storage | AWS Dependency |
|---------|-----------|------|---------|----------------|
| **Milvus DataNode** | mmjc-test | 2 | PVC (EBS) | ❌ Nenhuma |
| **Milvus IndexNode** | mmjc-test | 1 | PVC (EBS) | ❌ Nenhuma |
| **Milvus QueryNode** | mmjc-test | 1 | PVC (EBS) | ❌ Nenhuma |
| **Milvus MixCoord** | mmjc-test | 1 | PVC (EBS) | ❌ Nenhuma |
| **Milvus Proxy** | mmjc-test | 1 | - | ❌ Nenhuma |
| **Etcd** | mmjc-test | 3 | PVC (EBS) | ❌ Nenhuma |
| **Kafka** | mmjc-test | 3 | PVC (EBS) | ❌ Nenhuma |
| **Zookeeper** | mmjc-test | 3 | PVC (EBS) | ❌ Nenhuma |
| **MinIO** | mmjc-test | 4 | PVC (EBS) | 🟡 Opcional S3 |

**Características**:
- ✅ Rodam como StatefulSets ou Deployments
- ✅ Usam PersistentVolumeClaims (EBS)
- ✅ Comunicação intra-cluster
- ✅ Não dependem de serviços AWS externos

### 2.2 Serviços AWS EXTERNOS (Dependências Obrigatórias)

#### 🔴 OBRIGATÓRIOS

| Serviço AWS | Para que serve | Usado por | Alternativa Interna |
|-------------|----------------|-----------|---------------------|
| **RDS PostgreSQL 15** | Metadata DB | Airflow | ❌ Não (complexo) |
| **Redis as Cache (Redis 7)** | Message Broker | Airflow (Celery) | ❌ Não (recomendado externo) |
| **S3 Buckets** | Logs/DAGs | Airflow | 🟡 Pode usar PVC (não recomendado) |
| **EBS Volumes** | Persistent Storage | Todos StatefulSets | ❌ Não (managed pelo EKS) |
| **ALB (Load Balancer)** | Ingress | Airflow/Milvus | 🟡 Pode usar NodePort (não recomendado) |

#### 🟡 OPCIONAIS (Mas Recomendados)

| Serviço AWS | Para que serve | Usado por | Alternativa |
|-------------|----------------|-----------|-------------|
| **S3** | Object Storage | Milvus (substitui MinIO) | ✅ MinIO interno |
| **ECR** | Container Registry | Todas imagens | ✅ IBM ICR ou Docker Hub |
| **ACM** | Certificados SSL | ALB/Ingress | ✅ Cert-manager interno |
| **Route 53** | DNS | ALB | ✅ DNS externo qualquer |
| **CloudWatch** | Logs/Métricas | Monitoramento | ✅ Prometheus/Grafana |

### 2.3 Diagrama de Dependências

```
┌──────────────────────────────────────────────────────────────┐
│                        AWS EKS CLUSTER                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │         INTERNO (Não precisa AWS externo)               │ │
│  │                                                         │ │
│  │  • Milvus (5 componentes)                              │ │
│  │  • Etcd (3 pods)                                       │ │
│  │  • Kafka (3 pods)                                      │ │
│  │  • Zookeeper (3 pods)                                  │ │
│  │  • MinIO (4 pods) ← Opcional substituir por S3        │ │
│  │                                                         │ │
│  │  Storage: PVCs → EBS (AWS)                            │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │         AIRFLOW (Precisa AWS externo)                  │ │
│  │                                                         │ │
│  │  • API Server    ──→  RDS PostgreSQL (AWS)            │ │
│  │  • Scheduler     ──→  Redis as Cache (AWS)           │ │
│  │  • Workers       ──→  S3 Buckets (AWS)                │ │
│  │  • Triggerer                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────────┐
        │      SERVIÇOS AWS EXTERNOS          │
        │                                     │
        │  • RDS PostgreSQL (OBRIGATÓRIO)    │
        │  • Redis as Cache (OBRIGATÓRIO)    │
        │  • S3 (OBRIGATÓRIO para Airflow)   │
        │  • EBS (AUTOMÁTICO pelo EKS)       │
        │  • ALB (OBRIGATÓRIO para ingress)  │
        │  • ECR (OPCIONAL para imagens)     │
        └─────────────────────────────────────┘
```

---

## 🤖 3. CONFIGURAÇÃO GenAI com BEDROCK SONNET

### 3.1 Arquitetura GenAI

Atualmente **NÃO encontramos** referências explícitas a:
- Bedrock
- Anthropic
- Claude
- Sonnet
- LLM
- GenAI

no código-fonte atual.

### 3.2 Configuração Recomendada (Para Implementar)

Se você quiser adicionar GenAI com **AWS Bedrock + Claude Sonnet**:

#### A. Configurar AWS Bedrock Access

```bash
# 1. Habilitar modelo no Bedrock
aws bedrock list-foundation-models --region us-east-1 | \
    jq '.modelSummaries[] | select(.modelId | contains("claude"))'

# 2. Solicitar acesso ao modelo (console AWS)
# AWS Console → Bedrock → Model access → Request access
# Modelo: claude-3-5-sonnet-20241022 (ou mais recente)
```

#### B. Criar IAM Policy para Bedrock

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0"
      ]
    }
  ]
}
```

#### C. Adicionar ao Terraform

```hcl
# terraform/modules/bedrock/main.tf
resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.project_name}-bedrock-access"
  description = "Allow Airflow to invoke Bedrock models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_to_airflow" {
  role       = var.airflow_role_name
  policy_arn = aws_iam_policy.bedrock_access.arn
}
```

#### D. Configurar no Airflow (DAG Example)

```python
# dags/genai_example.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import boto3
import json

def invoke_claude_sonnet(**context):
    """Invoca Claude Sonnet via Bedrock"""

    bedrock = boto3.client(
        service_name='bedrock-runtime',
        region_name='us-east-1'
    )

    prompt = "Analise este texto: ..."

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4096,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ]
    })

    response = bedrock.invoke_model(
        modelId="anthropic.claude-3-5-sonnet-20241022-v2:0",
        body=body
    )

    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

with DAG(
    'genai_bedrock_example',
    start_date=datetime(2025, 1, 1),
    schedule_interval='@daily',
    catchup=False
) as dag:

    task_genai = PythonOperator(
        task_id='invoke_claude',
        python_callable=invoke_claude_sonnet
    )
```

#### E. Adicionar boto3 ao Container Airflow

```dockerfile
# Se precisar rebuildar a imagem
FROM apache/airflow:2.x.x

RUN pip install --no-cache-dir \
    boto3>=1.28.0 \
    botocore>=1.31.0
```

Ou via requirements.txt:
```txt
boto3>=1.28.0
botocore>=1.31.0
```

#### F. Variáveis de Ambiente

```yaml
# kustomize/airflow-test/base/deployment.yaml
env:
  - name: AWS_DEFAULT_REGION
    value: "us-east-1"
  - name: BEDROCK_MODEL_ID
    value: "anthropic.claude-3-5-sonnet-20241022-v2:0"
```

### 3.3 Modelos Disponíveis (Claude/Bedrock)

| Modelo | Model ID | Tokens | Custo Aprox | Uso |
|--------|----------|--------|-------------|-----|
| **Claude 3.5 Sonnet** | `anthropic.claude-3-5-sonnet-20241022-v2:0` | 200K | $$$ | Produção |
| Claude 3 Opus | `anthropic.claude-3-opus-20240229-v1:0` | 200K | $$$$ | Tarefas complexas |
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` | 200K | $$ | Balanceado |
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` | 200K | $ | Rápido/barato |

**Recomendação**: Claude 3.5 Sonnet (v2) para melhor custo-benefício

### 3.4 Segurança GenAI

```bash
# 1. NUNCA expor API keys no código
# 2. Usar IRSA (IAM Roles for Service Accounts)
# 3. Limitar modelos específicos na policy
# 4. Monitorar custos no AWS Cost Explorer
# 5. Implementar rate limiting
```

---

## 📝 4. INSTRUÇÕES DE MIGRAÇÃO

### 4.1 Passo a Passo Completo

#### ETAPA 1: Migrar Imagens (OBRIGATÓRIO)

```bash
# 1. Configurar target registry
vim config/migration.env
# Adicionar:
# TARGET_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com

# 2. Executar migração de imagens
./scripts/migrate-container-images.sh

# 3. Verificar
docker images | grep ecr
```

#### ETAPA 2: Atualizar Referências

```bash
# Editar kustomization.yaml
vim kustomize/airflow-test/kustomization.yaml
vim kustomize/milvus/kustomization.yaml

# Adicionar seção images:
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/mmjc-airflow-service
    newTag: latest
  - name: milvusdb/milvus
    newName: ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/milvus
    newTag: v2.5.15
```

#### ETAPA 3: Deploy Serviços AWS

```bash
# 1. Criar recursos AWS
cd terraform/environments/dev
terraform init
terraform apply

# Outputs esperados:
# - rds_endpoint
# - redis_endpoint
# - s3_bucket_names
```

#### ETAPA 4: Deploy Kubernetes

```bash
# 1. Deploy Milvus (interno - não precisa AWS além de EBS)
kubectl apply -k kustomize/milvus/

# 2. Verificar
kubectl get pods -n mmjc-test

# 3. Deploy Airflow (precisa RDS + Redis + S3)
kubectl apply -k kustomize/airflow-test/

# 4. Verificar
kubectl get pods -n airflow-test
```

#### ETAPA 5: Configurar GenAI (OPCIONAL)

```bash
# 1. Habilitar Bedrock
aws bedrock list-foundation-models --region us-east-1

# 2. Adicionar módulo Terraform
# (ver seção 3.2.C acima)

# 3. Deploy atualizado
terraform apply
kubectl rollout restart deployment -n airflow-test
```

### 4.2 Checklist de Validação

```bash
# ✅ Imagens migradas
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/milvus:v2.5.15

# ✅ RDS acessível
aws rds describe-db-instances --db-instance-identifier itau-airflow-postgres

# ✅ Redis acessível
aws elasticache describe-cache-clusters --cache-cluster-id itau-airflow-redis  # Redis as Cache

# ✅ S3 buckets criados
aws s3 ls | grep airflow

# ✅ Pods running
kubectl get pods -n mmjc-test
kubectl get pods -n airflow-test

# ✅ Services expostos
kubectl get ingress -A

# ✅ Storage bound
kubectl get pvc -A
```

---

## 🎯 5. RESUMO EXECUTIVO

### O que é INTERNO (não precisa AWS externo):

- ✅ Milvus (todos 5 componentes)
- ✅ Etcd (3 pods)
- ✅ Kafka (3 pods)
- ✅ Zookeeper (3 pods)
- ✅ MinIO (4 pods) - mas pode ser substituído por S3

**Storage**: Usam EBS via PVCs (managed pelo EKS)

### O que PRECISA AWS externo:

- 🔴 RDS PostgreSQL (Airflow metadata)
- 🔴 Redis as Cache (Airflow Celery)
- 🔴 S3 (Airflow logs/DAGs)
- 🔴 ALB (Ingress controller)
- 🔴 EBS (Persistent volumes)
- 🟡 ECR (opcional - pode usar IBM ICR)

### Imagens para migrar:

```
MMJC APPLICATIONS (OBRIGATÓRIAS - ICR privado):
- icr.io/mjc-cr/mmjc-agents:0.0.2
- icr.io/mjc-cr/mmjc-frontend:0.0.2
- icr.io/mjc-cr/mmjc-po:0.0.2
- icr.io/mjc-cr/mojoco-entities-manager:0.0.2
- icr.io/mjc-cr/mjc-mermaid-validator:1.0.17-llm-ready-amd64

MCP SERVERS (OBRIGATÓRIAS - ICR privado):
- icr.io/mjc-cr/go-mcp-git-s3:1.0.31
- icr.io/mjc-cr/arc-spring-api:3.1.2-amd64
- icr.io/mjc-cr/mcp-context-forge:0.9.0
- icr.io/mjc-cr/mcp-milvus-db:0.0.2

INFRASTRUCTURE (RECOMENDADAS):
- milvusdb/milvus:v2.5.15
- docker.io/milvusdb/etcd:3.5.18-r1
- docker.io/bitnami/kafka:3.1.0-debian-10-r52
- docker.io/bitnami/zookeeper:3.7.0-debian-10-r320
- minio/minio:RELEASE.2024-05-28T17-19-04Z
- redis:8.0.2
- zilliz/attu:v2.5.6
```

### GenAI/Bedrock:

- ❌ Não configurado atualmente
- ✅ Pode ser adicionado seguindo seção 3
- 🎯 Modelo recomendado: `anthropic.claude-3-5-sonnet-20241022-v2:0`

---

## 📚 Referências

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude on Bedrock](https://docs.anthropic.com/en/api/claude-on-amazon-bedrock)
- [Milvus Documentation](https://milvus.io/docs)
- [Apache Airflow on EKS](https://airflow.apache.org/docs/)

---

**Última atualização**: 2025-12-27
**Fonte**: Namespace mmjc-test
**Próximos passos**: Execute `./scripts/pull-and-retag-images.sh` para retagear imagens
