# Migração IBM IKS → AWS EKS
## Airflow Test + Milvus Dev

Este repositório contém todos os recursos e instruções para migrar as seguintes cargas de trabalho do IBM Cloud Kubernetes Service (IKS) para Amazon Elastic Kubernetes Service (EKS):

- **Airflow Test** (namespace: `airflow-test`)
- **Milvus Dev** (namespace: `milvus-dev` / componentes do `mmjc-dev`)

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Pré-requisitos](#pré-requisitos)
4. [Estrutura do Repositório](#estrutura-do-repositório)
5. [Guias de Instalação](#guias-de-instalação)
6. [Principais Diferenças IKS vs EKS](#principais-diferenças-iks-vs-eks)
7. [Troubleshooting](#troubleshooting)

## 🎯 Visão Geral

### O que será migrado

#### Airflow Test (namespace: airflow-test)
- **Deployments:**
  - `airflow-test-api-server` (API REST do Airflow)
  - `airflow-test-dag-processor` (Processador de DAGs)
  - `airflow-test-scheduler` (Scheduler)
  - `airflow-test-statsd` (Métricas)

- **StatefulSets:**
  - `airflow-test-triggerer` (Triggers assíncronos)
  - `airflow-test-worker` (Workers Celery)

- **Dependências Externas:**
  - PostgreSQL (RDS)
  - Redis (ElastiCache)
  - S3 (para logs e DAGs)

#### Milvus Dev (namespace: milvus-dev)
- **StatefulSets:**
  - `milvus-mmjc-dev-etcd` (3 réplicas)
  - `milvus-mmjc-dev-kafka` (3 réplicas)
  - `milvus-mmjc-dev-minio` (4 réplicas)
  - `milvus-mmjc-dev-zookeeper` (3 réplicas)

- **Deployments:**
  - `milvus-mmjc-dev-datanode` (2 réplicas)
  - `milvus-mmjc-dev-indexnode` (2 réplicas)
  - `milvus-mmjc-dev-mixcoord` (1 réplica)
  - `milvus-mmjc-dev-proxy` (1 réplica)
  - `milvus-mmjc-dev-querynode` (3 réplicas)
  - `my-attu` (UI do Milvus)
  - `mcp-milvus-db-dev` (MCP server)

## 🏗️ Arquitetura

### Arquitetura Atual (IBM IKS)

```
┌─────────────────────────────────────────────────────────────┐
│                     IBM Cloud IKS                            │
│  ┌──────────────────────┐  ┌────────────────────────────┐   │
│  │   Namespace:         │  │   Namespace:               │   │
│  │   airflow-test       │  │   mmjc-dev (Milvus)        │   │
│  │                      │  │                            │   │
│  │  - API Server        │  │  - Etcd (3)                │   │
│  │  - Scheduler         │  │  - Kafka (3)               │   │
│  │  - Workers (1)       │  │  - MinIO (4)               │   │
│  │  - Triggerer (1)     │  │  - Zookeeper (3)           │   │
│  │  - DAG Processor     │  │  - Milvus Components       │   │
│  └──────────────────────┘  └────────────────────────────┘   │
│                                                              │
│  Autenticação: IBMid / w3id                                  │
│  Storage: IBM Cloud Block Storage                            │
│  Ingress: IBM Cloud ALB                                      │
└─────────────────────────────────────────────────────────────┘
```

### Arquitetura Alvo (AWS EKS)

```
┌─────────────────────────────────────────────────────────────┐
│                       AWS EKS                                │
│  ┌──────────────────────┐  ┌────────────────────────────┐   │
│  │   Namespace:         │  │   Namespace:               │   │
│  │   airflow-test       │  │   milvus-dev               │   │
│  │                      │  │                            │   │
│  │  - API Server        │  │  - Etcd (3)                │   │
│  │  - Scheduler         │  │  - Kafka (3)               │   │
│  │  - Workers (1)       │  │  - MinIO (4) → S3*         │   │
│  │  - Triggerer (1)     │  │  - Zookeeper (3)           │   │
│  │  - DAG Processor     │  │  - Milvus Components       │   │
│  └──────────────────────┘  └────────────────────────────┘   │
│         ↓                            ↓                       │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │  RDS         │         │  S3 Buckets  │                  │
│  │  PostgreSQL  │         │  - Milvus    │                  │
│  │              │         │  - Airflow   │                  │
│  └──────────────┘         └──────────────┘                  │
│         ↓                                                    │
│  ┌──────────────┐                                            │
│  │ ElastiCache  │                                            │
│  │ Redis        │                                            │
│  └──────────────┘                                            │
│                                                              │
│  Autenticação: OAuth2 Proxy (OIDC)                          │
│  Storage: EBS gp3                                            │
│  Ingress: AWS ALB Ingress Controller                         │
└─────────────────────────────────────────────────────────────┘

* Opcional: Substituir MinIO interno por S3 nativo
```

## ✅ Pré-requisitos

### Ferramentas Necessárias

```bash
# Verificar instalação
terraform --version  # >= 1.5.0
kubectl version      # >= 1.27
aws --version        # AWS CLI v2
helm version         # >= 3.12
kustomize version    # >= 5.0
```

### Acessos Necessários

- ✅ Acesso ao cluster IBM IKS (mjc-cluster) com permissões de leitura
- ✅ Acesso ao cluster AWS EKS com permissões de administrador
- ✅ Credenciais AWS com permissões para criar:
  - RDS (PostgreSQL)
  - ElastiCache (Redis)
  - S3 Buckets
  - IAM Roles
- ✅ Acesso aos registros de container:
  - IBM Container Registry (icr.io)
  - AWS ECR ou registro público

### Informações Necessárias

Antes de iniciar, colete as seguintes informações:

1. **Do ambiente IBM IKS:**
   - ✅ Endpoints de serviços atuais
   - ✅ Strings de conexão de banco de dados
   - ✅ Configurações de secrets atuais
   - ✅ Configurações de recursos (CPU, memória, storage)

2. **Do ambiente AWS EKS:**
   - ✅ Nome do cluster EKS
   - ✅ Região AWS
   - ✅ VPC ID e Subnet IDs
   - ✅ Security Groups
   - ✅ Domínio para aplicações

## 📁 Estrutura do Repositório

```
ibm-iks-to-aws-eks-migration/
├── README.md                           # Este arquivo
├── docs/
│   └── pt-br/                          # Documentação em português
│       ├── 01-pre-requisitos.md        # Pré-requisitos detalhados
│       ├── 02-planejamento.md          # Planejamento da migração
│       ├── 03-terraform-setup.md       # Configuração da infraestrutura
│       ├── 04-airflow-migration.md     # Migração do Airflow
│       ├── 05-milvus-migration.md      # Migração do Milvus
│       ├── 06-oauth-setup.md           # Configuração OAuth (substitui IBMid)
│       ├── 07-validacao.md             # Validação pós-migração
│       └── 08-troubleshooting.md       # Resolução de problemas
│
├── airflow-test/                       # Exportações do namespace airflow-test
│   └── airflow-test-complete.yaml      # Export completo do kubectl
│
├── milvus-mmjc-dev/                    # Exportações dos componentes Milvus
│   ├── milvus-complete.yaml            # Export completo
│   └── milvus-workloads.yaml           # Workloads específicos
│
├── kustomize/                          # Manifestos Kubernetes (Kustomize)
│   ├── airflow-test/
│   │   ├── kustomization.yaml          # Configuração principal
│   │   ├── deployments.yaml            # (será gerado)
│   │   ├── statefulsets.yaml           # (será gerado)
│   │   ├── services.yaml               # (será gerado)
│   │   ├── configmaps.yaml             # (será gerado)
│   │   ├── patches/
│   │   │   ├── storage-class.yaml      # Patch para storage EKS
│   │   │   └── ingress-eks.yaml        # Patch para ALB
│   │   └── secrets/
│   │       ├── airflow-test-secrets-template.yaml
│   │       └── airflow-test-secrets-keys.json
│   ├── milvus/
│   │   └── (similar ao airflow)
│   └── overlays/
│       ├── dev/
│       └── prod/
│
├── terraform/                          # Infraestrutura como código
│   ├── modules/
│   │   ├── vpc/                        # VPC (opcional)
│   │   ├── eks/                        # Configurações EKS
│   │   ├── rds/                        # RDS PostgreSQL
│   │   ├── elasticache/                # Redis
│   │   └── s3/                         # S3 Buckets
│   └── environments/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars.example
│       └── prod/
│
└── scripts/                            # Scripts utilitários
    ├── extract-secrets-template.sh     # Extrair templates de secrets
    ├── split-k8s-resources.sh          # Separar recursos por tipo
    └── validate-migration.sh           # Validar migração
```

## 📚 Guias de Instalação

Siga os guias na ordem abaixo:

### 1. [Pré-requisitos](docs/pt-br/01-pre-requisitos.md)
Configure seu ambiente local e valide acessos necessários.

### 2. [Planejamento](docs/pt-br/02-planejamento.md)
Entenda as diferenças entre IBM IKS e AWS EKS e planeje a migração.

### 3. [Setup da Infraestrutura (Terraform)](docs/pt-br/03-terraform-setup.md)
Crie RDS, ElastiCache, S3 e outros recursos AWS necessários.

### 4. [Migração do Airflow](docs/pt-br/04-airflow-migration.md)
Migre o namespace airflow-test com downtime mínimo.

### 5. [Migração do Milvus](docs/pt-br/05-milvus-migration.md)
Migre os componentes do Milvus mantendo integridade dos dados.

### 6. [Configuração OAuth](docs/pt-br/06-oauth-setup.md)
Configure OAuth2 Proxy para substituir autenticação IBMid/w3id.

### 7. [Validação](docs/pt-br/07-validacao.md)
Valide que tudo está funcionando corretamente no EKS.

### 8. [Troubleshooting](docs/pt-br/08-troubleshooting.md)
Resolva problemas comuns durante e após a migração.

## 🔄 Principais Diferenças IKS vs EKS

| Aspecto | IBM IKS | AWS EKS |
|---------|---------|---------|
| **Autenticação** | IBMid / w3id | OAuth2 Proxy (OIDC) |
| **Ingress Controller** | IBM Cloud ALB | AWS ALB Ingress Controller |
| **Storage Class** | `ibmc-block-gold` | `gp3` (EBS) |
| **Load Balancer** | IBM Cloud LB | AWS ELB/ALB/NLB |
| **Registry** | `icr.io` | `ECR` ou público |
| **Postgres** | IBM Cloud Databases | RDS |
| **Redis** | IBM Cloud Databases | ElastiCache |
| **Object Storage** | IBM Cloud Object Storage | S3 |
| **Annotations** | `ingress.bluemix.net/*` | `alb.ingress.kubernetes.io/*` |

## 🚀 Início Rápido

Para migrar rapidamente (assumindo que o cluster EKS já existe):

```bash
# 1. Clonar este repositório
git clone <repo-url>
cd ibm-iks-to-aws-eks-migration

# 2. Configurar credenciais AWS
aws configure

# 3. Criar infraestrutura com Terraform
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com suas configurações
terraform init
terraform plan
terraform apply

# 4. Configurar secrets
cd ../../../kustomize/airflow-test/secrets
# Editar airflow-test-secrets-template.yaml com valores reais

# 5. Aplicar manifests do Airflow
cd ..
kubectl apply -k .

# 6. Validar deployment
kubectl get pods -n airflow-test
kubectl get svc -n airflow-test
```

## 📞 Suporte

Para dúvidas ou problemas:

1. Consulte o [guia de troubleshooting](docs/pt-br/08-troubleshooting.md)
2. Verifique os logs dos pods: `kubectl logs -n <namespace> <pod-name>`
3. Revise as configurações nos arquivos `kustomization.yaml`

## 📝 Checklist de Migração

- [ ] Pré-requisitos validados
- [ ] Infraestrutura AWS criada via Terraform
- [ ] Secrets configurados
- [ ] Airflow migrado e testado
- [ ] Milvus migrado e testado
- [ ] OAuth2 configurado
- [ ] DNS atualizado
- [ ] Monitoramento configurado
- [ ] Documentação atualizada
- [ ] Equipe treinada
- [ ] Ambiente antigo desprovisionado

## ⚠️ Notas Importantes

1. **Backup**: Sempre faça backup dos dados antes de migrar
2. **Teste**: Teste em ambiente de desenvolvimento antes de produção
3. **Downtime**: Planeje uma janela de manutenção para a migração
4. **Rollback**: Tenha um plano de rollback pronto
5. **Secrets**: Nunca commite secrets reais no repositório

## 📄 Licença

Este projeto é para uso interno da organização.

---

**Última atualização**: 2025-10-29
**Versão**: 1.0.0
**Autor**: Equipe de Migração IKS → EKS
