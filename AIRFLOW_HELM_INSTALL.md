# Instalação do Airflow via Helm Chart Oficial

Este guia mostra como instalar o Airflow no AWS EKS usando o **Helm Chart oficial**, baseado na configuração atual do `airflow-test`.

## Visão Geral

**Configuração atual (IBM IKS)**:
- Chart: `airflow-1.17.0`
- Versão Airflow: `3.0.2`
- Executor: `CeleryExecutor`
- Imagem: `icr.io/mjc-cr/mmjc-airflow-service:latest`
- Database: PostgreSQL externo
- Broker: Redis externo
- DAGs: PVC `mmjc-airflow-dags-dev`

## Pré-requisitos

### 1. Helm Instalado

```bash
# Verificar instalação
helm version

# Se não instalado:
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Adicionar Repositório do Airflow

```bash
# Adicionar repositório oficial
helm repo add apache-airflow https://airflow.apache.org

# Atualizar repositórios
helm repo update

# Verificar versões disponíveis
helm search repo apache-airflow/airflow --versions | head -10
```

### 3. Infraestrutura AWS Criada

- [ ] RDS PostgreSQL criado (via Terraform)
- [ ] Redis criado (via Terraform)
- [ ] S3 Buckets criados (logs, dags)
- [ ] IAM Role para Service Account (IRSA)
- [ ] Certificado SSL no ACM
- [ ] Namespace criado no EKS

## Instalação Passo a Passo

### Etapa 1: Criar Namespace

```bash
kubectl create namespace airflow-test

# Ou aplicar com labels
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: airflow-test
  labels:
    name: airflow-test
    environment: dev
    app: airflow
EOF
```

### Etapa 2: Criar Secrets

#### 2.1. PostgreSQL Connection

```bash
# Obter endpoint do RDS
RDS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw rds_endpoint)

# Criar secret
kubectl create secret generic airflow-postgres-connection-dev \
  --from-literal=connection="postgresql://airflow_admin:SENHA_FORTE@${RDS_ENDPOINT}:5432/airflow" \
  -n airflow-test

# Verificar
kubectl get secret airflow-postgres-connection-dev -n airflow-test -o yaml
```

#### 2.2. Redis Connection

```bash
# Obter endpoint do Redis
REDIS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw redis_endpoint)

# Criar secret
kubectl create secret generic airflow-redis-connection-dev \
  --from-literal=connection="redis://${REDIS_ENDPOINT}:6379/0" \
  -n airflow-test
```

#### 2.3. Fernet Key

```bash
# Gerar nova Fernet key
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Ou usar a existente do IKS (para compatibilidade)
# FERNET_KEY="sua-fernet-key-do-iks"

kubectl create secret generic airflow-fernet-key \
  --from-literal=fernet-key="$FERNET_KEY" \
  -n airflow-test
```

#### 2.4. Registry Secret (se usar registry privado)

```bash
# Para IBM ICR Brasil
kubectl create secret docker-registry all-icr-io-mmjc \
  --docker-server=br.icr.io \
  --docker-username=iamapikey \
  --docker-password=SUA_IBM_CLOUD_API_KEY \
  -n airflow-test

# Ou para AWS ECR
aws ecr get-login-password --region us-east-1 | \
  kubectl create secret docker-registry ecr-secret \
    --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password-stdin \
    -n airflow-test
```

#### 2.5. PostgreSQL CA Certificate (se necessário SSL)

```bash
# Se o RDS requer certificado SSL
# Baixar certificado RDS
curl -o /tmp/rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Criar secret
kubectl create secret generic airflow-postgres-cert-dev \
  --from-file=root.crt=/tmp/rds-ca.pem \
  -n airflow-test
```

### Etapa 3: Configurar values.yaml

```bash
# Copiar template
cp helm/airflow-values-aws-eks.yaml helm/airflow-values-dev.yaml

# Editar configurações
vim helm/airflow-values-dev.yaml
```

**Principais configurações a ajustar**:

```yaml
# Imagem
defaultAirflowRepository: br.icr.io/br-ibm-images/mmjc-airflow-service
defaultAirflowTag: latest

# Secrets criados
data:
  metadataSecretName: airflow-postgres-connection-dev
  brokerUrlSecretName: airflow-redis-connection-dev

registry:
  secretName: all-icr-io-mmjc

# Logging S3
config:
  logging:
    remote_base_log_folder: "s3://SEU-BUCKET-LOGS/airflow/logs"

# Ingress
ingress:
  hosts:
    - name: airflow-test.seu-dominio.com
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID

# Service Account com IRSA
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/airflow-test-role
```

### Etapa 4: Instalar via Helm

```bash
# Dry-run primeiro (validar configuração)
helm install airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --dry-run --debug > /tmp/helm-dry-run.yaml

# Revisar output
less /tmp/helm-dry-run.yaml

# Instalar
helm install airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --timeout 10m \
  --wait

# Output esperado:
# NAME: airflow-test
# NAMESPACE: airflow-test
# STATUS: deployed
# REVISION: 1
```

### Etapa 5: Monitorar Instalação

```bash
# Ver status do release
helm status airflow-test -n airflow-test

# Monitorar pods
kubectl get pods -n airflow-test -w

# Ver logs
kubectl logs -n airflow-test -l component=scheduler -f

# Ver eventos
kubectl get events -n airflow-test --sort-by='.lastTimestamp' | tail -20
```

### Etapa 6: Validar Instalação

```bash
# Todos os pods devem estar Running
kubectl get pods -n airflow-test

# Esperado:
# airflow-test-api-server-xxx        1/1     Running
# airflow-test-scheduler-xxx         1/1     Running
# airflow-test-dag-processor-xxx     1/1     Running
# airflow-test-worker-0              1/1     Running
# airflow-test-triggerer-0           1/1     Running
# airflow-test-statsd-xxx            1/1     Running

# Testar conexão com RDS
kubectl exec -it -n airflow-test deployment/airflow-test-scheduler -- \
  airflow db check

# Port-forward para UI
kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080 &

# Abrir no browser
open http://localhost:8080
```

## Upgrade do Airflow

### Atualizar Configuração

```bash
# Editar values
vim helm/airflow-values-dev.yaml

# Fazer upgrade
helm upgrade airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --timeout 10m \
  --wait

# Ver histórico
helm history airflow-test -n airflow-test
```

### Atualizar Versão do Chart

```bash
# Ver versões disponíveis
helm search repo apache-airflow/airflow --versions

# Upgrade para nova versão
helm upgrade airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml \
  --version 1.18.0 \
  --timeout 10m \
  --wait
```

### Atualizar Imagem Docker

```bash
# Editar values.yaml
vim helm/airflow-values-dev.yaml

# Mudar:
# defaultAirflowTag: v2.0.0

# Aplicar
helm upgrade airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml \
  --reuse-values \
  --set defaultAirflowTag=v2.0.0 \
  --wait
```

## Rollback

Se algo der errado:

```bash
# Ver histórico
helm history airflow-test -n airflow-test

# Rollback para revisão anterior
helm rollback airflow-test -n airflow-test

# Ou rollback para revisão específica
helm rollback airflow-test 1 -n airflow-test
```

## Migração de DAGs

### Opção 1: Migrar PVC Existente

Se tem dados no PVC `mmjc-airflow-dags-dev`:

```bash
# 1. Backup do PVC atual no IKS
kubectl exec -it -n airflow-test POD_NAME -- tar czf - /opt/airflow/dags > /tmp/dags-backup.tar.gz

# 2. Criar PVC no EKS
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mmjc-airflow-dags-dev
  namespace: airflow-test
spec:
  accessModes:
    - ReadWriteMany  # Requer EFS
  storageClassName: efs-sc
  resources:
    requests:
      storage: 10Gi
EOF

# 3. Restaurar dados
kubectl run -it --rm restore --image=busybox --restart=Never \
  --overrides='
{
  "spec": {
    "volumes": [{
      "name": "dags",
      "persistentVolumeClaim": {"claimName": "mmjc-airflow-dags-dev"}
    }],
    "containers": [{
      "name": "restore",
      "image": "busybox",
      "stdin": true,
      "stdinOnce": true,
      "tty": true,
      "volumeMounts": [{
        "name": "dags",
        "mountPath": "/dags"
      }]
    }]
  }
}' -- sh

# Dentro do pod:
# tar xzf - -C /dags < /tmp/dags-backup.tar.gz
```

### Opção 2: Git-Sync (Recomendado)

```yaml
# Em values.yaml
dags:
  gitSync:
    enabled: true
    repo: https://github.com/seu-org/airflow-dags.git
    branch: main
    subPath: dags
    wait: 60
    maxFailures: 3

    # Se repositório privado
    credentialsSecret: git-credentials

# Criar secret com credenciais Git
kubectl create secret generic git-credentials \
  --from-literal=GIT_SYNC_USERNAME=seu-usuario \
  --from-literal=GIT_SYNC_PASSWORD=seu-token \
  -n airflow-test
```

### Opção 3: S3 Bucket

```yaml
# Em values.yaml
config:
  core:
    dags_folder: "s3://SEU-BUCKET-DAGS/dags"

env:
  - name: AWS_DEFAULT_REGION
    value: "us-east-1"
```

## Troubleshooting

### Pods não inicializam

```bash
# Ver logs detalhados
kubectl describe pod POD_NAME -n airflow-test

# Ver eventos
kubectl get events -n airflow-test --sort-by='.lastTimestamp'

# Deletar e recriar
helm uninstall airflow-test -n airflow-test
helm install airflow-test apache-airflow/airflow \
  --namespace airflow-test \
  --values helm/airflow-values-dev.yaml
```

### Erro de conexão com RDS

```bash
# Testar conectividade
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -n airflow-test -- \
  psql -h RDS_ENDPOINT -U airflow_admin -d airflow

# Verificar secret
kubectl get secret airflow-postgres-connection-dev -n airflow-test -o jsonpath='{.data.connection}' | base64 -d
```

### Chart não encontrado

```bash
# Atualizar repositórios
helm repo update

# Listar repositórios
helm repo list

# Se não tem o repo, adicionar
helm repo add apache-airflow https://airflow.apache.org
```

## Desinstalação

```bash
# Desinstalar Airflow
helm uninstall airflow-test -n airflow-test

# Deletar PVCs (cuidado com dados!)
kubectl delete pvc --all -n airflow-test

# Deletar namespace
kubectl delete namespace airflow-test
```

## Referências

- [Airflow Helm Chart Documentation](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [Airflow Production Guide](https://airflow.apache.org/docs/apache-airflow/stable/production-deployment.html)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## Próximos Passos

Após instalar o Airflow via Helm:
1. Configurar ingress/DNS
2. Configurar OAuth2 (se necessário)
3. Migrar/configurar DAGs
4. Validar execução de tasks
5. Configurar monitoramento
