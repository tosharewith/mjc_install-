# Planejamento da Migração

Este documento detalha o planejamento necessário antes de executar a migração do IBM IKS para AWS EKS.

## Principais Diferenças: IKS vs EKS

### Comparativo de Recursos

| Aspecto | IBM IKS | AWS EKS |
|---------|---------|---------|
| **Autenticação** | IBMid / w3id | OAuth2 Proxy (OIDC) |
| **Ingress Controller** | IBM Cloud ALB | AWS ALB Ingress Controller |
| **Storage Class** | `ibmc-block-gold` | `gp3` (EBS) |
| **Load Balancer** | IBM Cloud LB | AWS ELB/ALB/NLB |
| **Registry** | `icr.io` | AWS ECR |
| **Postgres** | IBM Cloud Databases | Amazon RDS |
| **Redis** | IBM Cloud Databases | Amazon ElastiCache |
| **Object Storage** | IBM Cloud Object Storage | Amazon S3 |
| **Annotations** | `ingress.bluemix.net/*` | `alb.ingress.kubernetes.io/*` |

### Componentes que Precisam Adaptação

#### 1. PersistentVolumes

```yaml
# IBM IKS
storageClassName: ibmc-block-gold

# AWS EKS
storageClassName: gp3
```

#### 2. Ingress

```yaml
# IBM IKS
annotations:
  ingress.bluemix.net/ssl-services: "ssl-service=airflow-test"

# AWS EKS
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
```

#### 3. Imagens Docker

```yaml
# IBM IKS
image: icr.io/mjc-cr/mmjc-airflow-service:latest

# AWS EKS (opção ECR)
image: ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/mmjc-airflow-service:latest

# AWS EKS (opção IBM ICR)
image: br.icr.io/br-ibm-images/mmjc-airflow-service:latest
```

## Arquitetura Alvo

### Visão Geral

```
┌─────────────────────────────────────────────────────────────┐
│                       AWS EKS                                │
│  ┌──────────────────────┐  ┌────────────────────────────┐   │
│  │   Namespace:         │  │   Namespace:               │   │
│  │   airflow-test       │  │   milvus-dev               │   │
│  │                      │  │                            │   │
│  │  - API Server        │  │  - Etcd (3)                │   │
│  │  - Scheduler         │  │  - Kafka (3)               │   │
│  │  - Workers (1)       │  │  - MinIO (4)               │   │
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
```

## Componentes da Migração

### 1. Serviços AWS Externos (Obrigatórios)

#### RDS PostgreSQL
- **Para**: Airflow metadata database
- **Configuração**:
  - Engine: PostgreSQL 15
  - Instance class: db.t3.medium (mínimo)
  - Storage: 100GB gp3
  - Multi-AZ: Sim (produção)
  - Backup: 7 dias

#### ElastiCache Redis
- **Para**: Airflow Celery message broker
- **Configuração**:
  - Engine: Redis 7.x
  - Node type: cache.t3.medium (mínimo)
  - Nodes: 2 (com failover)
  - Automatic failover: Sim

#### S3 Buckets
- **Para**: Logs e DAGs do Airflow
- **Buckets necessários**:
  - `{project}-airflow-logs`
  - `{project}-airflow-dags`
  - `{project}-milvus-data` (opcional)

#### EBS Volumes
- **Para**: Persistent storage de todos os StatefulSets
- **Configuração**:
  - Tipo: gp3
  - IOPS: 3000 (padrão)
  - Throughput: 125 MB/s

### 2. Serviços Internos ao Cluster

#### Milvus
- Todos os componentes rodam dentro do cluster
- Usa PVCs para storage persistente
- Comunicação intra-cluster
- Não depende de serviços AWS externos

#### Componentes:
- DataNode (2 réplicas)
- IndexNode (1 réplica)
- QueryNode (1 réplica)
- MixCoord (1 réplica)
- Proxy (1 réplica)
- Etcd (3 réplicas)
- Kafka (3 réplicas)
- Zookeeper (3 réplicas)
- MinIO (4 réplicas)

## Estratégia de Migração

### Abordagem Recomendada: Big Bang com Rollback Plan

#### Vantagens
- Migração completa de uma vez
- Menos complexidade operacional
- Estado consistente

#### Desvantagens
- Requer janela de manutenção
- Downtime necessário

### Timeline Sugerida

```
Fase 1: Preparação (1-2 dias)
├── Criar recursos AWS via Terraform
├── Migrar imagens Docker
├── Validar conectividade
└── Preparar scripts de migração

Fase 2: Migração (4-6 horas)
├── Backup dados atuais
├── Deploy Milvus no EKS
├── Migrar dados Milvus (se necessário)
├── Deploy Airflow no EKS
├── Validar serviços
└── Atualizar DNS

Fase 3: Validação (1-2 horas)
├── Testes de funcionalidade
├── Verificar logs
├── Validar DAGs
└── Monitorar métricas

Fase 4: Rollback (se necessário)
└── Reverter DNS para ambiente anterior
```

## Plano de Rollback

### Trigger Conditions

Executar rollback se:
- Mais de 50% dos pods não inicializarem em 30 minutos
- Falha na conexão com RDS/Redis
- Erros críticos nos logs do Airflow
- DAGs não executarem corretamente

### Procedimento de Rollback

```bash
# 1. Reverter DNS
# Apontar de volta para ambiente IBM IKS

# 2. Parar pods no EKS
kubectl scale deployment --all --replicas=0 -n airflow-test
kubectl scale statefulset --all --replicas=0 -n milvus-dev

# 3. Validar ambiente anterior
# Verificar que ambiente IBM IKS está funcional

# 4. Comunicar rollback
# Notificar stakeholders

# 5. Investigar causa
# Analisar logs e métricas
```

## Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Perda de dados durante migração | Alto | Baixo | Backup completo antes da migração |
| Problemas de conectividade RDS/Redis | Alto | Médio | Testar conectividade antes de migrar |
| Incompatibilidade de versões | Médio | Médio | Validar versões no ambiente de dev |
| Quotas AWS insuficientes | Alto | Baixo | Verificar quotas antes de iniciar |
| Problemas de autenticação | Médio | Médio | Configurar OAuth2 antecipadamente |
| Imagens não disponíveis | Alto | Baixo | Migrar imagens antes da migração |

## Checklist Pré-Migração

### Preparação
- [ ] Todos os pré-requisitos validados (01-pre-requisitos.md)
- [ ] Backup completo realizado
- [ ] Janela de manutenção aprovada
- [ ] Stakeholders notificados
- [ ] Plano de comunicação definido

### Infraestrutura AWS
- [ ] VPC e subnets criadas
- [ ] Security groups configurados
- [ ] RDS PostgreSQL criado e testado
- [ ] ElastiCache Redis criado e testado
- [ ] S3 buckets criados
- [ ] IAM roles configuradas
- [ ] EKS cluster disponível

### Imagens e Código
- [ ] Imagens migradas para registry alvo
- [ ] Manifests Kubernetes adaptados
- [ ] Scripts de migração testados
- [ ] Configurações validadas

### Segurança
- [ ] Secrets preparados
- [ ] Certificados SSL configurados
- [ ] OAuth2 testado
- [ ] Network policies revisadas

## Próximos Passos

Após o planejamento, prossiga para [03-terraform-setup.md](03-terraform-setup.md) para criar a infraestrutura AWS.
