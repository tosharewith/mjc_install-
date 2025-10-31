# Validação Pós-Migração

Este documento detalha os procedimentos de validação após a migração completa.

## Visão Geral

A validação deve confirmar que:
- Todos os componentes estão funcionando
- Serviços externos (RDS, Redis, S3) estão acessíveis
- Dados foram migrados corretamente
- Autenticação funciona
- Performance é adequada

## Checklist Geral

### Infraestrutura AWS

```bash
# RDS PostgreSQL
aws rds describe-db-instances \
  --db-instance-identifier itau-airflow-milvus-airflow-postgres \
  --query 'DBInstances[0].DBInstanceStatus'
# Esperado: "available"

# Redis as Cache
aws elasticache describe-cache-clusters \
  --cache-cluster-id itau-airflow-milvus-airflow-redis \
  --query 'CacheClusters[0].CacheClusterStatus'
# Esperado: "available"

# S3 Buckets
aws s3 ls | grep airflow
# Deve listar 3 buckets
```

### Cluster EKS

```bash
# Cluster status
aws eks describe-cluster \
  --name SEU_CLUSTER_EKS \
  --query 'cluster.status'
# Esperado: "ACTIVE"

# Nodes
kubectl get nodes
# Todos devem estar Ready

# Namespaces
kubectl get namespaces | grep -E "airflow|milvus"
# airflow-test   Active
# milvus-dev     Active
```

## Validação do Airflow

### 1. Pods

```bash
# Listar todos os pods
kubectl get pods -n airflow-test

# Esperado: Todos Running
# airflow-test-api-server-xxx        1/1     Running
# airflow-test-scheduler-xxx         1/1     Running
# airflow-test-dag-processor-xxx     1/1     Running
# airflow-test-worker-0              1/1     Running
# airflow-test-triggerer-0           1/1     Running
# airflow-test-statsd-xxx            1/1     Running

# Verificar nenhum pod em CrashLoopBackOff ou Error
kubectl get pods -n airflow-test --field-selector=status.phase!=Running
# Não deve retornar nada
```

### 2. Logs

```bash
# Scheduler (sem erros críticos)
kubectl logs -n airflow-test -l component=scheduler --tail=50 | grep -i error

# Workers
kubectl logs -n airflow-test -l component=worker --tail=50 | grep -i error

# API Server
kubectl logs -n airflow-test -l component=api-server --tail=50 | grep -i error
```

### 3. Conectividade

```bash
# Testar conexão com RDS
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow db check
# Esperado: "Connection successful"

# Testar conexão com Redis
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  python -c "from airflow.configuration import conf; from redis import Redis; r = Redis.from_url(conf.get('celery', 'broker_url')); print(r.ping())"
# Esperado: "True"

# Testar acesso ao S3
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  aws s3 ls s3://BUCKET_LOGS/
# Deve listar conteúdo
```

### 4. UI e API

```bash
# Port-forward
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080 &

# Health check
curl http://localhost:8080/health
# Esperado: {"metadatabase":{"status":"healthy"},...}

# Listar DAGs
curl http://localhost:8080/api/v1/dags | jq '.dags | length'
# Deve retornar número de DAGs

# Abrir UI
open http://localhost:8080
# Verificar:
# - Login funciona (se OAuth configurado)
# - DAGs aparecem
# - Logs são visíveis
# - Tasks executam
```

### 5. DAGs e Tasks

```bash
# Listar DAGs
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow dags list
# Deve listar todos os DAGs

# Trigger uma DAG de teste
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow dags trigger example_dag

# Verificar execução
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow dags state example_dag $(date +%Y-%m-%d)
# Esperado: "success" ou "running"
```

## Validação do Milvus

### 1. Pods

```bash
# Listar todos os pods
kubectl get pods -n milvus-dev

# Verificar StatefulSets
kubectl get statefulset -n milvus-dev
# Todos devem ter READY = DESIRED (ex: 3/3)

# Verificar Deployments
kubectl get deployment -n milvus-dev
# Todos devem ter READY = DESIRED
```

### 2. PVCs

```bash
# Listar PVCs
kubectl get pvc -n milvus-dev

# Todos devem estar Bound
kubectl get pvc -n milvus-dev --field-selector=status.phase!=Bound
# Não deve retornar nada
```

### 3. Componentes

```bash
# Etcd cluster health
kubectl exec -it -n milvus-dev milvus-mmjc-test-etcd-0 -- \
  etcdctl endpoint health --cluster
# Esperado: 3 endpoints healthy

# Kafka cluster
kubectl exec -it -n milvus-dev milvus-mmjc-test-kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9092 --list
# Deve listar topics do Milvus

# MinIO (ou verificar S3)
kubectl exec -it -n milvus-dev milvus-mmjc-test-minio-0 -- \
  mc ls local/
# Deve listar buckets
```

### 4. API do Milvus

```bash
# Port-forward
kubectl port-forward -n milvus-dev svc/milvus-mmjc-test-proxy 19530:19530 &

# Testar com Python
python3 << 'EOF'
from pymilvus import connections, utility

try:
    connections.connect(host='localhost', port='19530')
    print("✓ Conexão estabelecida")
    print(f"✓ Versão Milvus: {utility.get_server_version()}")
    print(f"✓ Collections: {utility.list_collections()}")
except Exception as e:
    print(f"✗ Erro: {e}")
EOF
```

### 5. Attu UI

```bash
# Port-forward
kubectl port-forward -n milvus-dev svc/my-attu 8000:80 &

# Abrir no browser
open http://localhost:8000

# Verificar:
# - UI carrega
# - Pode conectar ao Milvus
# - Collections aparecem (se existirem)
# - Pode fazer queries
```

## Validação de Integração

### 1. Airflow → Milvus

Se tem DAGs que usam Milvus:

```bash
# Testar DAG que interage com Milvus
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow dags trigger milvus_integration_dag

# Verificar logs
kubectl logs -n airflow-test -l component=worker -f | grep -i milvus
```

### 2. Logs no S3

```bash
# Verificar que logs estão sendo escritos
aws s3 ls s3://BUCKET_LOGS/logs/ --recursive | tail -10

# Download de um log de exemplo
aws s3 cp s3://BUCKET_LOGS/logs/dag_id/run_id/task_id/attempt_1.log /tmp/
cat /tmp/attempt_1.log
```

### 3. DAGs no S3 (se aplicável)

```bash
# Verificar DAGs no S3
aws s3 ls s3://BUCKET_DAGS/dags/

# Verificar que Airflow lê do S3
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  ls -la /opt/airflow/dags/
```

## Validação de Autenticação

### OAuth2 Proxy (se configurado)

```bash
# Verificar pods OAuth2 Proxy
kubectl get pods -n airflow-test -l app=oauth2-proxy

# Testar endpoint público
curl -I https://airflow.exemplo.com
# Deve retornar 302 (redirect para login)

# Após login no browser, verificar:
# - Redirecionamento funciona
# - Cookie é definido
# - Acesso ao Airflow é permitido
```

## Validação de Performance

### Airflow

```bash
# CPU e Memória dos pods
kubectl top pods -n airflow-test

# Scheduler deve estar consumindo recursos consistentemente
# Workers devem variar baseado em carga
```

### Milvus

```bash
# CPU e Memória
kubectl top pods -n milvus-dev

# Query performance (exemplo)
python3 << 'EOF'
from pymilvus import connections, Collection
import time

connections.connect(host='localhost', port='19530')
coll = Collection("your_collection")

start = time.time()
results = coll.search(
    data=[[0.1] * 128],
    anns_field="embedding",
    param={"metric_type": "L2", "params": {"nprobe": 10}},
    limit=10
)
elapsed = time.time() - start
print(f"Query latency: {elapsed:.3f}s")
EOF
```

## Validação de Segurança

```bash
# Security Groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Network Policies
kubectl get networkpolicies -A

# Secrets não devem estar em plain text
kubectl get secrets -n airflow-test -o yaml | grep -i password
# Deve estar em base64
```

## Script de Validação Automatizada

Use o script fornecido:

```bash
./scripts/validate-migration.sh

# Output esperado:
# ✓ RDS PostgreSQL disponível
# ✓ Redis as Cache disponível
# ✓ S3 buckets acessíveis
# ✓ Namespace airflow-test OK
# ✓ Namespace milvus-dev OK
# ✓ Todos os pods Airflow Running (6/6)
# ✓ Todos os pods Milvus Running (20/20)
# ✓ PVCs Bound (13/13)
# ✓ Ingress configurado
# ✓ OAuth2 Proxy Running (se configurado)
#
# RESULTADO: ✓ Migração validada com sucesso!
```

## Monitoramento Contínuo

### CloudWatch (se configurado)

```bash
# Ver métricas do RDS
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=itau-airflow-postgres \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Prometheus/Grafana (se configurado)

```bash
# Port-forward para Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Abrir dashboards
open http://localhost:3000

# Verificar:
# - CPU/Memória dos pods
# - Latência de requests
# - Taxa de erros
```

## Checklist Final

### Airflow
- [ ] Todos os pods Running
- [ ] Scheduler processa DAGs
- [ ] Workers executam tasks
- [ ] UI acessível
- [ ] API responde
- [ ] Logs no S3
- [ ] Conexão com RDS OK
- [ ] Conexão com Redis OK

### Milvus
- [ ] Todos os StatefulSets saudáveis
- [ ] Todos os Deployments Running
- [ ] PVCs Bound
- [ ] Etcd cluster healthy (3/3)
- [ ] Kafka cluster healthy (3/3)
- [ ] API responde
- [ ] Attu UI acessível

### Infraestrutura
- [ ] RDS disponível
- [ ] Redis disponível
- [ ] S3 acessível
- [ ] Ingress configurado
- [ ] DNS configurado
- [ ] SSL válido

### Segurança
- [ ] Autenticação funciona
- [ ] Secrets configurados
- [ ] Network policies OK
- [ ] Security groups corretos

## Próximos Passos

Após validação completa:
1. Documentar qualquer issue encontrado em [08-troubleshooting.md](08-troubleshooting.md)
2. Configurar monitoramento contínuo
3. Treinar equipe
4. Planejar desativação do ambiente IKS
