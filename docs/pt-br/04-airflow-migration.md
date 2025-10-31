# Migração do Airflow

Este documento detalha o processo de migração do Airflow Test do IBM IKS para AWS EKS.

## Visão Geral

O namespace `airflow-test` contém:
- **Deployments**: API Server, Scheduler, DAG Processor, StatsD
- **StatefulSets**: Workers (Celery), Triggerer
- **Dependências Externas**: PostgreSQL (RDS), Redis as Cache, S3

## Pré-requisitos

Antes de iniciar esta migração:

- [ ] Infraestrutura AWS criada via Terraform (03-terraform-setup.md)
- [ ] RDS PostgreSQL acessível e validado
- [ ] Redis as Cache acessível e validado
- [ ] S3 buckets criados
- [ ] Imagens Docker migradas para registry alvo
- [ ] Namespace `airflow-test` criado no EKS
- [ ] kubectl configurado para cluster EKS

## Componentes do Airflow

### Deployments (6 réplicas total)

| Componente | Réplicas | Função |
|------------|----------|--------|
| API Server | 1 | REST API do Airflow |
| Scheduler | 1 | Agenda e dispara DAGs |
| DAG Processor | 1 | Processa arquivos DAG |
| StatsD | 1 | Coleta métricas |

### StatefulSets

| Componente | Réplicas | Função |
|------------|----------|--------|
| Workers | 1 | Executa tasks (Celery) |
| Triggerer | 1 | Triggers assíncronos |

## Estratégia de Migração

### Abordagem: Blue-Green com Downtime Mínimo

1. **Preparação**: Deploy no EKS (sem tráfego)
2. **Sincronização**: Copiar DAGs e configurações
3. **Cutover**: Parar Airflow no IKS, iniciar no EKS
4. **Validação**: Verificar funcionamento
5. **Rollback Plan**: Reverter se necessário

## Passo a Passo

### Etapa 1: Preparar Configurações

#### 1.1. Coletar Informações do Ambiente Atual (IKS)

```bash
# Conectar ao cluster IKS
ibmcloud ks cluster config --cluster mjc-cluster

# Exportar configurações atuais
kubectl get configmaps -n airflow-test -o yaml > /tmp/airflow-configmaps-iks.yaml
kubectl get secrets -n airflow-test -o yaml > /tmp/airflow-secrets-iks.yaml

# Exportar variáveis de ambiente
kubectl get deployment airflow-test-api-server -n airflow-test -o jsonpath='{.spec.template.spec.containers[0].env}' | jq > /tmp/airflow-env-iks.json
```

#### 1.2. Obter Endpoints AWS

```bash
# Do Terraform
cd terraform/environments/dev
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
S3_LOGS_BUCKET=$(terraform output -json s3_buckets | jq -r '.logs')
S3_DAGS_BUCKET=$(terraform output -json s3_buckets | jq -r '.dags')

echo "RDS: $RDS_ENDPOINT"
echo "Redis: $REDIS_ENDPOINT"
echo "S3 Logs: $S3_LOGS_BUCKET"
echo "S3 DAGs: $S3_DAGS_BUCKET"
```

### Etapa 2: Configurar Secrets no EKS

#### 2.1. Criar Secret para Conexão com RDS

```bash
# Conectar ao cluster EKS
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# Criar secret para PostgreSQL
kubectl create secret generic airflow-postgresql \
  --from-literal=connection="postgresql://airflow_admin:SENHA@$RDS_ENDPOINT:5432/airflow" \
  -n airflow-test

# Ou via arquivo YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: airflow-postgresql
  namespace: airflow-test
type: Opaque
stringData:
  connection: "postgresql://airflow_admin:SENHA@${RDS_ENDPOINT}:5432/airflow"
EOF
```

#### 2.2. Criar Secret para Redis

```bash
kubectl create secret generic airflow-redis \
  --from-literal=connection="redis://${REDIS_ENDPOINT}:6379/0" \
  -n airflow-test
```

#### 2.3. Criar Secret para S3

```bash
# Se usar IRSA (recomendado), não precisa de secret
# Se usar access keys:
kubectl create secret generic airflow-s3 \
  --from-literal=aws-access-key-id=AKIA... \
  --from-literal=aws-secret-access-key=... \
  -n airflow-test
```

#### 2.4. Criar Fernet Key

```bash
# Usar a mesma Fernet key do ambiente IKS (para descriptografar secrets)
kubectl create secret generic airflow-fernet-key \
  --from-literal=fernet-key="FERNET_KEY_DO_IKS" \
  -n airflow-test
```

### Etapa 3: Sincronizar DAGs

#### 3.1. Copiar DAGs do IKS para S3

```bash
# Opção 1: Se DAGs estão em Git (recomendado)
# Não precisa copiar, Airflow lerá do Git

# Opção 2: Se DAGs estão em PVC no IKS
# Copiar para máquina local
kubectl cp airflow-test/airflow-test-scheduler-xxx:/opt/airflow/dags ./dags-backup

# Upload para S3
aws s3 sync ./dags-backup s3://${S3_DAGS_BUCKET}/dags/
```

#### 3.2. Configurar Airflow para Ler DAGs do S3

Editar ConfigMap ou variáveis de ambiente:

```yaml
env:
  - name: AIRFLOW__CORE__DAGS_FOLDER
    value: "s3://${S3_DAGS_BUCKET}/dags"
  - name: AIRFLOW__LOGGING__REMOTE_LOGGING
    value: "True"
  - name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
    value: "s3://${S3_LOGS_BUCKET}/logs"
```

### Etapa 4: Inicializar Database

#### 4.1. Migrar Schema do PostgreSQL

```bash
# Se quiser preservar histórico (recomendado)
# Fazer dump do banco IKS
kubectl exec -it airflow-test-scheduler-xxx -n airflow-test -- \
  pg_dump -h HOST_IKS -U airflow -d airflow > /tmp/airflow-db-dump.sql

# Restaurar no RDS
kubectl run -it --rm psql-client --image=postgres:15 --restart=Never -- \
  psql -h $RDS_ENDPOINT -U airflow_admin -d airflow < /tmp/airflow-db-dump.sql
```

**OU** inicializar do zero (perde histórico):

```bash
# Executar migrations do Airflow
kubectl run -it --rm airflow-init --image=apache/airflow:2.x.x --restart=Never -- \
  airflow db init
```

### Etapa 5: Deploy do Airflow no EKS

#### 5.1. Atualizar Kustomization

```bash
cd kustomize/airflow-test

# Verificar configuração
cat kustomization.yaml
```

Garantir que as imagens estão corretas:

```yaml
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: br.icr.io/br-ibm-images/mmjc-airflow-service
    newTag: latest
```

#### 5.2. Aplicar Manifests

```bash
# Dry-run primeiro
kubectl kustomize kustomize/airflow-test/ | kubectl apply --dry-run=client -f -

# Aplicar
kubectl apply -k kustomize/airflow-test/

# Ou via script de migração
./migrate.sh --component airflow
```

#### 5.3. Aguardar Pods

```bash
# Monitorar pods
kubectl get pods -n airflow-test -w

# Aguardar todos ficarem prontos
kubectl wait --for=condition=ready pod -l app=airflow -n airflow-test --timeout=600s
```

### Etapa 6: Validar Deployment

#### 6.1. Verificar Status dos Pods

```bash
# Status de todos os pods
kubectl get pods -n airflow-test

# Esperado: Todos Running
# airflow-test-api-server-xxx        1/1     Running
# airflow-test-scheduler-xxx         1/1     Running
# airflow-test-dag-processor-xxx     1/1     Running
# airflow-test-worker-0              1/1     Running
# airflow-test-triggerer-0           1/1     Running
# airflow-test-statsd-xxx            1/1     Running
```

#### 6.2. Verificar Logs

```bash
# Scheduler
kubectl logs -n airflow-test -l component=scheduler --tail=100

# Workers
kubectl logs -n airflow-test -l component=worker --tail=100

# API Server
kubectl logs -n airflow-test -l component=api-server --tail=100
```

#### 6.3. Testar Conectividade

```bash
# Port-forward para UI
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080 &

# Abrir no browser
open http://localhost:8080

# Ou testar via curl
curl http://localhost:8080/health
```

#### 6.4. Validar DAGs

```bash
# Listar DAGs via API
curl http://localhost:8080/api/v1/dags | jq

# Trigger uma DAG de teste
curl -X POST http://localhost:8080/api/v1/dags/test_dag/dagRuns
```

### Etapa 7: Cutover (Mudança de Tráfego)

#### 7.1. Parar Airflow no IKS

```bash
# Conectar ao IKS
ibmcloud ks cluster config --cluster mjc-cluster

# Escalar para zero
kubectl scale deployment --all --replicas=0 -n airflow-test
kubectl scale statefulset --all --replicas=0 -n airflow-test

# Verificar que parou
kubectl get pods -n airflow-test
```

#### 7.2. Atualizar DNS

```bash
# Atualizar DNS para apontar para ALB do EKS
# Exemplo (Route 53):
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch file://dns-change.json
```

#### 7.3. Validar Novo Endpoint

```bash
# Testar novo endpoint
curl https://airflow-test.seu-dominio.com/health
```

### Etapa 8: Monitoramento Pós-Migração

```bash
# Monitorar pods
kubectl get pods -n airflow-test -w

# Monitorar logs em tempo real
kubectl logs -n airflow-test -l component=scheduler -f

# Monitorar métricas
kubectl top pods -n airflow-test
```

## Rollback

Se algo der errado:

```bash
# 1. Reverter DNS para IKS
# (usar console DNS ou CLI)

# 2. Reativar Airflow no IKS
ibmcloud ks cluster config --cluster mjc-cluster
kubectl scale deployment --all --replicas=1 -n airflow-test
kubectl scale statefulset --all --replicas=1 -n airflow-test

# 3. Validar que IKS está funcional
kubectl get pods -n airflow-test
```

## Troubleshooting

### Pods não inicializam

```bash
# Ver eventos
kubectl get events -n airflow-test --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod airflow-test-scheduler-xxx -n airflow-test
```

### Erro de conexão com RDS

```bash
# Testar conectividade
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n airflow-test -- \
  psql -h $RDS_ENDPOINT -U airflow_admin -d airflow -c "SELECT 1;"
```

### DAGs não aparecem

```bash
# Verificar configuração do DAG folder
kubectl exec -it airflow-test-scheduler-xxx -n airflow-test -- \
  airflow config get-value core dags_folder

# Verificar acesso ao S3
kubectl exec -it airflow-test-scheduler-xxx -n airflow-test -- \
  aws s3 ls s3://${S3_DAGS_BUCKET}/dags/
```

## Checklist de Validação

- [ ] Todos os pods estão Running
- [ ] Scheduler está processando DAGs
- [ ] Workers executam tasks
- [ ] UI é acessível
- [ ] DAGs aparecem na interface
- [ ] Logs aparecem no S3
- [ ] Conexão com RDS funcionando
- [ ] Conexão com Redis funcionando
- [ ] Tasks executam com sucesso

## Próximos Passos

Após migrar o Airflow, prossiga para [05-milvus-migration.md](05-milvus-migration.md).
