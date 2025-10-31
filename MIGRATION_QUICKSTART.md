# Guia Rápido: Migração IKS → EKS via Helm

Este é um guia rápido para migrar Airflow e Milvus do IBM IKS para AWS EKS usando Helm Charts oficiais.

## 📋 Visão Geral

**Ambientes atuais no IKS (mjc-cluster)**:
- `airflow-test` → Airflow 3.0.2 (via Helm chart 1.17.0)
- `mmjc-test` → Milvus 2.5.15 (via Helm chart 4.2.57)

**Estratégia**: Replicar instalação exata usando os mesmos Helm Charts, adaptando apenas:
- Storage Class (ibmc-block-gold → gp3)
- Node selectors (IBM worker pools → EKS node groups)
- Secrets/Conexões (RDS, Redis, S3)

## 🚀 Instalação Rápida

### 1. Preparar AWS EKS

```bash
# Conectar ao cluster EKS
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# Verificar
kubectl cluster-info
kubectl get nodes
```

### 2. Criar Infraestrutura AWS (Terraform)

```bash
cd terraform/environments/dev

# Editar variáveis
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Aplicar
terraform init
terraform plan
terraform apply

# Salvar outputs
terraform output > ../../outputs.txt
```

### 3. Instalar Airflow via Helm

```bash
# Ver guia completo: AIRFLOW_HELM_INSTALL.md

# Adicionar repo
helm repo add apache-airflow https://airflow.apache.org
helm repo update

# Criar namespace
kubectl create namespace airflow-test

# Criar secrets (ajustar com outputs do Terraform)
kubectl create secret generic airflow-postgres-connection-dev \
  --from-literal=connection="postgresql://user:pass@RDS_ENDPOINT:5432/airflow" \
  -n airflow-test

kubectl create secret generic airflow-redis-connection-dev \
  --from-literal=connection="redis://REDIS_ENDPOINT:6379/0" \
  -n airflow-test

# Instalar
helm install airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-aws-eks.yaml \
  --version 1.17.0 \
  --timeout 10m \
  --wait

# Validar
kubectl get pods -n airflow-test
```

### 4. Instalar Milvus via Helm

```bash
# Ver guia completo: MILVUS_HELM_INSTALL.md

# Adicionar repo
helm repo add milvus https://zilliztech.github.io/milvus-helm/
helm repo update

# Criar namespace
kubectl create namespace mmjc-test

# Instalar
helm install milvus-mmjc-test milvus/milvus \
  --namespace mmjc-test \
  --values helm/milvus-values-aws-eks.yaml \
  --version 4.2.57 \
  --timeout 15m \
  --wait

# Validar
kubectl get pods -n mmjc-test | grep milvus
```

### 5. Validar

```bash
# Airflow
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080 &
curl http://localhost:8080/health

# Milvus
kubectl port-forward -n mmjc-test svc/milvus-mmjc-test-proxy 19530:19530 &
python3 -c "from pymilvus import connections; connections.connect('localhost', '19530'); print('OK')"
```

## 📚 Documentação Completa

### Guias de Instalação via Helm (Novos!)
- **[AIRFLOW_HELM_INSTALL.md](AIRFLOW_HELM_INSTALL.md)** - Instalação completa do Airflow via Helm
- **[MILVUS_HELM_INSTALL.md](MILVUS_HELM_INSTALL.md)** - Instalação completa do Milvus via Helm

### Guias Passo a Passo
1. **[Pré-requisitos](docs/pt-br/01-pre-requisitos.md)** - Ferramentas e acessos necessários
2. **[Planejamento](docs/pt-br/02-planejamento.md)** - Diferenças IKS vs EKS
3. **[Setup Terraform](docs/pt-br/03-terraform-setup.md)** - Criar RDS, Redis, S3
4. **[Migração Airflow](docs/pt-br/04-airflow-migration.md)** - Migrar Airflow
5. **[Migração Milvus](docs/pt-br/05-milvus-migration.md)** - Migrar Milvus
6. **[OAuth Setup](docs/pt-br/06-oauth-setup.md)** - Configurar autenticação
7. **[Validação](docs/pt-br/07-validacao.md)** - Validar migração
8. **[Troubleshooting](docs/pt-br/08-troubleshooting.md)** - Resolver problemas

### Configurações Helm
- **[helm/airflow-values-aws-eks.yaml](helm/airflow-values-aws-eks.yaml)** - Template Airflow
- **[helm/milvus-values-aws-eks.yaml](helm/milvus-values-aws-eks.yaml)** - Template Milvus

## 🔧 Arquivos Importantes

### Estrutura Atual
```
.
├── README.md                        # Documentação principal
├── MIGRATION_QUICKSTART.md          # Este arquivo
├── AIRFLOW_HELM_INSTALL.md          # Guia Airflow Helm
├── MILVUS_HELM_INSTALL.md           # Guia Milvus Helm
│
├── docs/pt-br/                      # Documentação detalhada
│   ├── 01-pre-requisitos.md
│   ├── 02-planejamento.md
│   ├── 03-terraform-setup.md
│   ├── 04-airflow-migration.md
│   ├── 05-milvus-migration.md
│   ├── 06-oauth-setup.md
│   ├── 07-validacao.md
│   └── 08-troubleshooting.md
│
├── helm/                            # Helm values
│   ├── airflow-values-aws-eks.yaml
│   └── milvus-values-aws-eks.yaml
│
├── terraform/                       # Infraestrutura
│   └── environments/dev/
│       ├── main.tf
│       └── terraform.tfvars
│
└── scripts/                         # Scripts auxiliares
    ├── migrate.sh
    └── validate-migration.sh
```

## ⚙️ Configurações Principais

### Airflow
```yaml
# helm/airflow-values-aws-eks.yaml (principais itens)
airflowVersion: "3.0.2"
executor: "CeleryExecutor"
defaultAirflowRepository: br.icr.io/br-ibm-images/mmjc-airflow-service
defaultAirflowTag: latest

postgresql:
  enabled: false  # Usar RDS

redis:
  enabled: false  # Usar Redis as Cache

data:
  metadataSecretName: airflow-postgres-connection-dev
  brokerUrlSecretName: airflow-redis-connection-dev
```

### Milvus
```yaml
# helm/milvus-values-aws-eks.yaml (principais itens)
image:
  all:
    repository: milvusdb/milvus
    tag: v2.5.15

cluster:
  enabled: true

# Storage
etcd:
  persistence:
    storageClass: gp3
kafka:
  persistence:
    storageClass: gp3
minio:
  persistence:
    storageClass: gp3
```

## 📊 Checklist de Migração

### Preparação
- [ ] Cluster EKS criado
- [ ] kubectl configurado para EKS
- [ ] Helm instalado (>= 3.12)
- [ ] Terraform instalado (>= 1.5)

### Infraestrutura
- [ ] Terraform aplicado
- [ ] RDS PostgreSQL criado
- [ ] Redis as Cache criado
- [ ] S3 Buckets criados
- [ ] Outputs do Terraform salvos

### Airflow
- [ ] Namespace `airflow-test` criado
- [ ] Secrets criados (PostgreSQL, Redis, Fernet)
- [ ] Registry secret criado (se usar ICR/ECR privado)
- [ ] Helm chart instalado
- [ ] Pods Running
- [ ] UI acessível
- [ ] DAGs carregando

### Milvus
- [ ] Namespace `mmjc-test` criado
- [ ] Storage Class `gp3` disponível
- [ ] Helm chart instalado
- [ ] StatefulSets saudáveis (Etcd, Kafka, MinIO)
- [ ] Deployments Running
- [ ] API respondendo
- [ ] (Opcional) Dados migrados

### Validação
- [ ] Airflow scheduler processando DAGs
- [ ] Airflow workers executando tasks
- [ ] Milvus API acessível
- [ ] Logs sendo escritos no S3
- [ ] Monitoramento configurado

## 🆘 Troubleshooting Rápido

### Pods não inicializam
```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'
```

### Erro de conexão com RDS/Redis
```bash
# Testar de dentro do cluster
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n airflow-test -- \
  psql -h RDS_ENDPOINT -U airflow_admin -d airflow

kubectl run -it --rm debug --image=redis:7 --restart=Never -n airflow-test -- \
  redis-cli -h REDIS_ENDPOINT ping
```

### PVC não faz bind
```bash
# Verificar storage class
kubectl get sc gp3

# Verificar EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

## 📝 Comandos Úteis

```bash
# Ver releases Helm
helm list -A

# Ver valores usados
helm get values airflow-test -n airflow-test
helm get values milvus-mmjc-test -n mmjc-test

# Upgrade
helm upgrade airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-aws-eks.yaml \
  --reuse-values

# Rollback
helm rollback airflow-test -n airflow-test

# Ver histórico
helm history airflow-test -n airflow-test
```

## 🎯 Próximos Passos

1. **Documentação Detalhada**: Leia os guias em `docs/pt-br/`
2. **Helm Charts**: Use `AIRFLOW_HELM_INSTALL.md` e `MILVUS_HELM_INSTALL.md`
3. **Customização**: Edite `helm/*-values-aws-eks.yaml` conforme necessário
4. **Terraform**: Configure infraestrutura AWS
5. **Deploy**: Instale via Helm
6. **Valide**: Use checklist acima

## 📞 Suporte

- Ver logs detalhados: `kubectl logs -n NAMESPACE POD_NAME`
- Ver eventos: `kubectl get events -n NAMESPACE`
- Troubleshooting completo: [docs/pt-br/08-troubleshooting.md](docs/pt-br/08-troubleshooting.md)

---

**Última atualização**: 2025-10-30
**Namespaces**: `airflow-test` e `mmjc-test`
**Método**: Helm Charts oficiais
