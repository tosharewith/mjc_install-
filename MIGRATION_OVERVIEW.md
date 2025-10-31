# 📦 Visão Completa da Migração IBM IKS → AWS EKS

## 🎯 Objetivo

Migrar as seguintes cargas de trabalho do IBM Cloud Kubernetes Service para AWS EKS de forma **automatizada**, **segura** e com **downtime mínimo**:

- ✅ **Airflow Test** (namespace: `airflow-test`)
- ✅ **Milvus Dev** (namespace: `milvus-dev`)

## 📊 Componentes Migrados

### Airflow Test

| Componente | Tipo | Réplicas | Descrição |
|------------|------|----------|-----------|
| `airflow-test-api-server` | Deployment | 1-2 | REST API do Airflow |
| `airflow-test-scheduler` | Deployment | 1 | Agendador de DAGs |
| `airflow-test-dag-processor` | Deployment | 1 | Processador de DAGs |
| `airflow-test-statsd` | Deployment | 1 | Métricas StatsD |
| `airflow-test-worker` | StatefulSet | 1 | Workers Celery |
| `airflow-test-triggerer` | StatefulSet | 1 | Triggers assíncronos |

**Dependências:**
- PostgreSQL 15 (RDS)
- Redis 7 as Cache
- S3 para logs e DAGs

### Milvus Dev

| Componente | Tipo | Réplicas | Descrição |
|------------|------|----------|-----------|
| `milvus-mmjc-test-etcd` | StatefulSet | 3 | Armazenamento de metadados |
| `milvus-mmjc-test-kafka` | StatefulSet | 3 | Message broker |
| `milvus-mmjc-test-minio` | StatefulSet | 4 | Object storage interno |
| `milvus-mmjc-test-zookeeper` | StatefulSet | 3 | Coordenação distribuída |
| `milvus-mmjc-test-datanode` | Deployment | 2 | Nós de dados |
| `milvus-mmjc-test-indexnode` | Deployment | 2 | Nós de indexação |
| `milvus-mmjc-test-querynode` | Deployment | 3 | Nós de query |
| `milvus-mmjc-test-mixcoord` | Deployment | 1 | Coordenador misto |
| `milvus-mmjc-test-proxy` | Deployment | 1 | Proxy API |
| `my-attu` | Deployment | 1 | UI do Milvus |
| `mcp-milvus-db-dev` | Deployment | 1 | MCP server |

**Opção de Otimização:**
- Substituir MinIO interno por S3 nativo (recomendado para produção)

## 🏗️ Infraestrutura AWS Criada

### Via Terraform

```
┌─────────────────────────────────────────────┐
│ VPC (opcional - pode usar existente)       │
│  - Subnets públicas (3 AZs)                │
│  - Subnets privadas (3 AZs)                │
│  - NAT Gateways                            │
│  - Internet Gateway                        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ RDS PostgreSQL 15                           │
│  - Multi-AZ: Sim                           │
│  - Encrypted: Sim                          │
│  - Backup automático: 7 dias               │
│  - Instance: db.t3.medium (ajustável)      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Redis as Cache (Redis 7)                    │
│  - Engine: Redis                           │
│  - Node type: cache.t3.medium              │
│  - Encryption in-transit: Sim              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ S3 Buckets                                  │
│  - ${project}-airflow-logs                 │
│  - ${project}-airflow-dags                 │
│  - ${project}-milvus-data                  │
│  Todos com:                                │
│   - Versioning: Enabled                    │
│   - Encryption: AES-256                    │
│   - Lifecycle policies                     │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ IAM Roles & Policies                        │
│  - IRSA para acesso S3                     │
│  - Políticas de least privilege            │
└─────────────────────────────────────────────┘
```

## 🔄 Processo de Migração Automatizado

### Fluxo do Script Master (`./migrate.sh`)

```
1️⃣  Verificação de Pré-requisitos
    ✓ Ferramentas instaladas (terraform, kubectl, aws, helm)
    ✓ Credenciais AWS válidas
    ✓ Acesso ao cluster EKS
    ✓ Arquivo de configuração presente

2️⃣  Criação de Infraestrutura (Terraform)
    ✓ RDS PostgreSQL
    ✓ Redis as Cache
    ✓ S3 Buckets
    ✓ Security Groups
    ✓ IAM Roles

3️⃣  Geração de Secrets
    ✓ Fernet Key (Airflow)
    ✓ JWT Secret
    ✓ Webserver Secret Key
    ✓ Connection strings (RDS, Redis)
    ✓ Certificado raiz do RDS

4️⃣  Migração do Airflow
    ✓ Criar namespace
    ✓ Aplicar secrets
    ✓ Aplicar ConfigMaps
    ✓ Aplicar Deployments
    ✓ Aplicar StatefulSets
    ✓ Configurar Ingress
    ✓ Aguardar pods ficarem prontos

5️⃣  Migração do Milvus
    ✓ Criar namespace
    ✓ Aplicar secrets
    ✓ Aplicar StatefulSets (etcd, kafka, minio, zookeeper)
    ✓ Aplicar Deployments
    ✓ Configurar Services
    ✓ Aguardar cluster convergir

6️⃣  Configuração OAuth2
    ✓ Instalar OAuth2 Proxy (Helm)
    ✓ Configurar Ingress com autenticação
    ✓ Configurar callbacks

7️⃣  Validação
    ✓ Verificar namespaces
    ✓ Verificar pods (todos Running)
    ✓ Testar conexões (RDS, Redis)
    ✓ Validar PVCs
    ✓ Testar APIs
    ✓ Verificar logs
```

## 🚀 Como Executar

### Modo Automático (Recomendado)

```bash
# 1. Configurar ambiente
cp config/migration.env.example config/migration.env
vim config/migration.env  # Editar com suas configurações

# 2. Executar migração completa
./migrate.sh

# 3. Validar
./scripts/validate-migration.sh
```

### Modo Dry-Run (Teste)

```bash
# Simular sem fazer mudanças
./migrate.sh --dry-run
```

### Modo Parcial

```bash
# Pular criação de infraestrutura (se já existe)
./migrate.sh --skip-terraform

# Migrar apenas Airflow
./migrate.sh --skip-milvus

# Migrar apenas Milvus
./migrate.sh --skip-airflow
```

## 📁 Estrutura de Arquivos Criada

```
ibm-iks-to-aws-eks-migration/
├── README.md                      # Documentação principal
├── QUICKSTART.md                  # Guia rápido
├── MIGRATION_OVERVIEW.md          # Este arquivo
├── migrate.sh                     # ⭐ Script master de migração
├── .gitignore                     # Protege secrets
│
├── config/
│   ├── migration.env.example      # Template de configuração
│   ├── migration.env              # Configuração (gitignored)
│   └── secrets/                   # Secrets gerados (gitignored)
│       ├── fernet-key
│       ├── jwt-secret
│       ├── webserver-secret-key
│       ├── postgres-connection
│       └── redis-connection
│
├── docs/
│   └── pt-br/                     # Documentação em português
│       ├── 01-pre-requisitos.md
│       ├── 02-planejamento.md
│       ├── 03-terraform-setup.md
│       ├── 04-airflow-migration.md
│       ├── 05-milvus-migration.md
│       ├── 06-oauth-setup.md
│       ├── 07-validacao.md
│       └── 08-troubleshooting.md
│
├── airflow-test/
│   └── airflow-test-complete.yaml # Export do kubectl (IKS)
│
├── milvus-mmjc-test/
│   ├── milvus-complete.yaml       # Export do kubectl (IKS)
│   └── milvus-workloads.yaml
│
├── kustomize/
│   ├── airflow-test/
│   │   ├── kustomization.yaml     # Configuração Kustomize
│   │   ├── patches/               # Patches para EKS
│   │   │   ├── storage-class.yaml
│   │   │   ├── ingress-eks.yaml
│   │   │   └── oauth-ingress.yaml
│   │   └── secrets/
│   │       ├── generated-secrets.yaml
│   │       └── airflow-test-secrets-keys.json
│   ├── milvus/
│   │   └── (estrutura similar)
│   └── overlays/
│       ├── dev/
│       └── prod/
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── rds/
│   │   ├── elasticache/     # Redis as Cache
│   │   └── s3/
│   └── environments/
│       ├── dev/
│       │   ├── main.tf             # ⭐ Configuração principal
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── terraform.tfvars.example
│       └── prod/
│
└── scripts/
    ├── extract-secrets-template.sh  # Extrair secrets sem dados
    ├── split-k8s-resources.sh       # Separar YAMLs
    ├── generate-secrets.sh          # ⭐ Gerar secrets
    ├── setup-oauth-proxy.sh         # ⭐ Configurar OAuth
    └── validate-migration.sh        # ⭐ Validar migração
```

## 🔐 Gestão de Secrets

### Secrets Criados Automaticamente

```yaml
# Airflow
- airflow-test-fernet-key           # Criptografia de senhas
- airflow-test-jwt-secret           # Autenticação JWT
- airflow-test-webserver-secret-key # Session cookie
- airflow-postgres-connection-test  # String de conexão RDS
- airflow-redis-connection-test     # String de conexão Redis
- airflow-postgres-cert-test        # Certificado SSL RDS

# S3 (via IRSA - IAM Roles for Service Accounts)
- ServiceAccount com annotation para acesso S3
```

### Secrets NÃO commitados

O `.gitignore` protege:
- `config/secrets/` (todos arquivos)
- `config/migration.env` (configuração com senhas)
- `*-secrets.yaml` (manifests com dados)
- `*.key`, `*.pem`, `*.crt` (certificados)

## 🔄 Diferenças IKS → EKS

| Aspecto | IBM IKS (Origem) | AWS EKS (Destino) |
|---------|------------------|-------------------|
| **Auth** | IBMid / w3id | OAuth2 Proxy (OIDC) |
| **Ingress** | IBM ALB (`ingress.bluemix.net/*`) | AWS ALB (`alb.ingress.kubernetes.io/*`) |
| **Storage** | `ibmc-block-gold` | `gp3` (EBS) |
| **LB** | IBM Cloud LB | AWS ELB/ALB/NLB |
| **Registry** | `icr.io` | ECR ou público |
| **Postgres** | IBM Cloud Databases | RDS |
| **Redis** | IBM Cloud Databases | Redis as Cache |
| **Object Storage** | IBM COS | S3 |
| **DNS** | IBM Cloud Internet Services | Route53 |
| **Monitoring** | IBM Cloud Monitoring | CloudWatch + Prometheus |

## ✅ Checklist de Migração

### Pré-Migração
- [ ] Backup completo dos dados no IKS
- [ ] Documentar configurações atuais
- [ ] Validar credenciais AWS
- [ ] Configurar `migration.env`
- [ ] Testar em ambiente dev primeiro

### Durante Migração
- [ ] Executar `./migrate.sh --dry-run` primeiro
- [ ] Executar `./migrate.sh`
- [ ] Monitorar logs durante deployment
- [ ] Validar cada fase

### Pós-Migração
- [ ] Executar `./scripts/validate-migration.sh`
- [ ] Testar DAGs do Airflow
- [ ] Testar queries no Milvus
- [ ] Validar conectividade (RDS, Redis, S3)
- [ ] Testar OAuth se configurado
- [ ] Configurar DNS
- [ ] Configurar monitoramento
- [ ] Configurar alertas
- [ ] Documentar mudanças
- [ ] Treinar equipe

### Cleanup (após validação completa)
- [ ] Manter ambiente IKS rodando por 1-2 semanas
- [ ] Validar billing/custos AWS
- [ ] Desprovisionar recursos IKS
- [ ] Atualizar documentação
- [ ] Arquivar backups

## 📊 Recursos AWS

### Recursos Provisionados

| Recurso | Especificação |
|---------|---------------|
| **RDS PostgreSQL** | db.t3.medium, 100GB |
| **Redis as Cache** | cache.t3.medium |
| **S3 Storage** | Buckets com versioning e lifecycle |
| **EBS Volumes** | gp3, volumes para StatefulSets |
| **ALB** | Application Load Balancer |
| **Data Transfer** | Entre serviços e internet |

> **Nota**: Configure alertas de billing no AWS Cost Explorer para monitorar custos

## 🆘 Suporte e Troubleshooting

### Logs

```bash
# Airflow Scheduler
kubectl logs -n airflow-test -l component=scheduler -f

# Airflow Worker
kubectl logs -n airflow-test -l component=worker -f

# Milvus Proxy
kubectl logs -n milvus-dev -l app.kubernetes.io/component=proxy -f

# Todos eventos
kubectl get events -n airflow-test --sort-by='.lastTimestamp'
```

### Comandos Úteis

```bash
# Status geral
kubectl get pods -A | grep -E "airflow|milvus"

# Port-forward Airflow
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080

# Port-forward Milvus
kubectl port-forward -n milvus-dev svc/milvus-mmjc-test 19530:19530

# Executar comando em pod
kubectl exec -it -n airflow-test <pod-name> -- bash

# Testar conectividade RDS
kubectl run -it --rm pg-test --image=postgres:15 --restart=Never -- \
  psql -h <RDS_ENDPOINT> -U airflow_admin -d airflow
```

### Scripts de Diagnóstico

```bash
# Validação completa
./scripts/validate-migration.sh

# Testar OAuth
curl -I https://airflow-test.seu-dominio.com

# Ver outputs do Terraform
cd terraform/environments/dev
terraform output
```

## 🎓 Documentação Adicional

- **README.md**: Visão geral e estrutura
- **QUICKSTART.md**: Guia rápido automatizado
- **docs/pt-br/**: Guias detalhados passo-a-passo
- **Scripts**: Comentados inline

## 🚀 Próximos Passos Recomendados

1. **Monitoramento**
   - Configurar CloudWatch Dashboards
   - Instalar Prometheus + Grafana
   - Configurar alertas

2. **Segurança**
   - Habilitar Pod Security Standards
   - Configurar Network Policies
   - Implementar OPA/Gatekeeper

3. **Alta Disponibilidade**
   - Multi-AZ para StatefulSets
   - RDS Multi-AZ (já incluído)
   - Redis com réplicas

4. **Backup**
   - Snapshot automático EBS
   - Backup RDS (já incluído)
   - Velero para backup K8s

5. **CI/CD**
   - GitOps com ArgoCD/Flux
   - Pipelines automatizados
   - Ambientes staging/prod

## 📞 Contatos

- **Documentação**: Ver `docs/pt-br/`
- **Issues**: GitHub Issues
- **Troubleshooting**: `docs/pt-br/08-troubleshooting.md`

---

**Versão**: 1.0.0
**Data**: 2025-10-29
**Automação**: Alto nível
**Status**: ✅ Pronto para uso
