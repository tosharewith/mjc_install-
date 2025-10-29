# 🚀 Guia Rápido de Migração

Este guia permite migrar o Airflow Test e Milvus Dev do IBM IKS para AWS EKS de forma automatizada (assumindo que o cluster EKS já existe).

## ⚡ Pré-requisitos

```bash
# 1. Clonar o repositório
git clone <repo-url>
cd ibm-iks-to-aws-eks-migration

# 2. Verificar ferramentas instaladas
terraform --version  # >= 1.5.0
kubectl version      # >= 1.27
aws --version        # AWS CLI v2
helm version         # >= 3.12

# 3. Configurar credenciais AWS
aws configure
# OU
export AWS_PROFILE=seu-perfil

# 4. Configurar kubectl para o cluster EKS
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# 5. Testar acesso
kubectl cluster-info
```

## 📝 Configuração

```bash
# 1. Copiar arquivo de configuração
cp config/migration.env.example config/migration.env

# 2. Editar configuração
vim config/migration.env  # ou seu editor preferido
```

**Configurações Mínimas Necessárias:**

```bash
# AWS
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# EKS
EKS_CLUSTER_NAME=seu-cluster-eks
ENVIRONMENT=dev

# Database
DB_USERNAME=airflow_admin
DB_PASSWORD=SUA_SENHA_FORTE_AQUI

# Domain
BASE_DOMAIN=exemplo.com.br
AIRFLOW_SUBDOMAIN=airflow-test
```

## 🎯 Migração Automatizada

### Opção 1: Migração Completa Automática

```bash
# Executar migração completa
./migrate.sh
```

Isso irá:
1. ✅ Criar RDS PostgreSQL
2. ✅ Criar ElastiCache Redis
3. ✅ Criar S3 Buckets
4. ✅ Gerar secrets automaticamente
5. ✅ Migrar Airflow
6. ✅ Migrar Milvus
7. ✅ Configurar OAuth2 Proxy
8. ✅ Validar deployment

### Opção 2: Migração Passo-a-Passo

Se preferir controle manual:

#### Passo 1: Criar Infraestrutura

```bash
cd terraform/environments/dev

# Editar variáveis se necessário
vim terraform.tfvars

# Aplicar Terraform
terraform init
terraform plan
terraform apply
```

#### Passo 2: Gerar Secrets

```bash
cd ../../../
./scripts/generate-secrets.sh
```

#### Passo 3: Migrar Airflow

```bash
# Criar namespace
kubectl create namespace airflow-test

# Aplicar secrets e manifests
kubectl apply -k kustomize/airflow-test/

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l app=airflow -n airflow-test --timeout=600s
```

#### Passo 4: Migrar Milvus

```bash
# Criar namespace
kubectl create namespace milvus-dev

# Aplicar manifests
kubectl apply -k kustomize/milvus/

# Aguardar StatefulSets
kubectl get pods -n milvus-dev -w
```

#### Passo 5: Validar

```bash
./scripts/validate-migration.sh
```

## 🧪 Teste Rápido

```bash
# Port-forward para Airflow
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080 &

# Abrir no browser
open http://localhost:8080

# Verificar DAGs
curl http://localhost:8080/api/v1/dags

# Verificar health
kubectl get pods -n airflow-test
kubectl get pods -n milvus-dev
```

## 🔧 Troubleshooting Rápido

### Pods não inicializam

```bash
# Ver logs
kubectl logs -n airflow-test -l component=scheduler

# Ver eventos
kubectl get events -n airflow-test --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n airflow-test <pod-name>
```

### Erro de conexão com RDS

```bash
# Verificar security groups
aws rds describe-db-instances --db-instance-identifier <nome>

# Testar conectividade
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql -h <RDS_ENDPOINT> -U airflow_admin -d airflow
```

### Erro de conexão com Redis

```bash
# Verificar endpoint
terraform output redis_endpoint

# Testar conectividade
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -- \
  redis-cli -h <REDIS_ENDPOINT> ping
```

## 📊 Monitoramento

```bash
# Dashboard dos pods
kubectl get pods -A | grep -E "airflow|milvus"

# Logs em tempo real
kubectl logs -n airflow-test -l component=scheduler -f

# Métricas
kubectl top pods -n airflow-test
kubectl top pods -n milvus-dev
```

## 🎉 Conclusão

Após a migração bem-sucedida:

1. ✅ Airflow rodando em: `https://airflow-test.seu-dominio.com`
2. ✅ Milvus acessível via ClusterIP
3. ✅ Dados persistidos em RDS, Redis e S3
4. ✅ OAuth2 configurado (se habilitado)

## 🚨 Rollback Rápido

Se algo der errado:

```bash
# Deletar recursos do Airflow
kubectl delete namespace airflow-test

# Deletar recursos do Milvus
kubectl delete namespace milvus-dev

# Destruir infraestrutura (CUIDADO!)
cd terraform/environments/dev
terraform destroy
```

## 📚 Próximos Passos

- [ ] Configurar monitoramento (CloudWatch, Prometheus)
- [ ] Configurar alertas
- [ ] Ajustar auto-scaling (HPA)
- [ ] Configurar backups automáticos
- [ ] Documentar runbooks operacionais
- [ ] Treinar equipe
- [ ] Desprovisionar ambiente IBM IKS (após validação)

## 💡 Dicas

1. **Dry-run primeiro**: Execute `./migrate.sh --dry-run` para simular
2. **Backup**: Sempre faça backup antes de deletar o ambiente antigo
3. **DNS**: Atualize DNS somente após validação completa
4. **Custos**: Monitore custos AWS para evitar surpresas
5. **Logs**: Mantenha logs do ambiente antigo por 30 dias

## 🆘 Suporte

- **Documentação completa**: `docs/pt-br/`
- **Troubleshooting**: `docs/pt-br/08-troubleshooting.md`
- **Validação**: `./scripts/validate-migration.sh`
- **Logs**: `kubectl logs -n <namespace> <pod>`

---

**Complexidade**: Média
**Automação**: Alto nível
