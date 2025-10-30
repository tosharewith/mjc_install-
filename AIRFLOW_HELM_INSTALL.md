# Instalação do Airflow via Helm Chart Oficial

Este guia mostra como instalar o Airflow no AWS EKS usando o **Helm Chart oficial**, baseado na configuração atual do `airflow-dev`.

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
- [ ] ElastiCache Redis criado (via Terraform)
- [ ] S3 Buckets criados (logs, dags)
- [ ] IAM Role para Service Account (IRSA)
- [ ] Certificado SSL no ACM
- [ ] Namespace criado no EKS

## Instalação Passo a Passo

### Etapa 1: Criar Namespace

```bash
kubectl create namespace airflow-dev

# Ou aplicar com labels
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: airflow-dev
  labels:
    name: airflow-dev
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
  -n airflow-dev

# Verificar
kubectl get secret airflow-postgres-connection-dev -n airflow-dev -o yaml
```

#### 2.2. Redis Connection

```bash
# Obter endpoint do Redis
REDIS_ENDPOINT=$(cd terraform/environments/dev && terraform output -raw redis_endpoint)

# Criar secret
kubectl create secret generic airflow-redis-connection-dev \
  --from-literal=connection="redis://${REDIS_ENDPOINT}:6379/0" \
  -n airflow-dev
```

#### 2.3. Fernet Key

```bash
# Gerar nova Fernet key
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Ou usar a existente do IKS (para compatibilidade)
# FERNET_KEY="sua-fernet-key-do-iks"

kubectl create secret generic airflow-fernet-key \
  --from-literal=fernet-key="$FERNET_KEY" \
  -n airflow-dev
```

#### 2.4. Registry Secret (se usar registry privado)

```bash
# Para IBM ICR Brasil
kubectl create secret docker-registry all-icr-io-mmjc \
  --docker-server=br.icr.io \
  --docker-username=iamapikey \
  --docker-password=SUA_IBM_CLOUD_API_KEY \
  -n airflow-dev

# Ou para AWS ECR
aws ecr get-login-password --region us-east-1 | \
  kubectl create secret docker-registry ecr-secret \
    --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password-stdin \
    -n airflow-dev
```

#### 2.5. PostgreSQL CA Certificate (se necessário SSL)

```bash
# Se o RDS requer certificado SSL
# Baixar certificado RDS
curl -o /tmp/rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Criar secret
kubectl create secret generic airflow-postgres-cert-dev \
  --from-file=root.crt=/tmp/rds-ca.pem \
  -n airflow-dev
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
    - name: airflow-dev.seu-dominio.com
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID

# Service Account com IRSA
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/airflow-dev-role
```

### Etapa 4: Instalar via Helm

```bash
# Dry-run primeiro (validar configuração)
helm install airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --dry-run --debug > /tmp/helm-dry-run.yaml

# Revisar output
less /tmp/helm-dry-run.yaml

# Instalar
helm install airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --timeout 10m \
  --wait

# Output esperado:
# NAME: airflow-dev
# NAMESPACE: airflow-dev
# STATUS: deployed
# REVISION: 1
```

### Etapa 5: Monitorar Instalação

```bash
# Ver status do release
helm status airflow-dev -n airflow-dev

# Monitorar pods
kubectl get pods -n airflow-dev -w

# Ver logs
kubectl logs -n airflow-dev -l component=scheduler -f

# Ver eventos
kubectl get events -n airflow-dev --sort-by='.lastTimestamp' | tail -20
```

### Etapa 6: Validar Instalação

```bash
# Todos os pods devem estar Running
kubectl get pods -n airflow-dev

# Esperado:
# airflow-dev-api-server-xxx        1/1     Running
# airflow-dev-scheduler-xxx         1/1     Running
# airflow-dev-dag-processor-xxx     1/1     Running
# airflow-dev-worker-0              1/1     Running
# airflow-dev-triggerer-0           1/1     Running
# airflow-dev-statsd-xxx            1/1     Running

# Testar conexão com RDS
kubectl exec -it -n airflow-dev deployment/airflow-dev-scheduler -- \
  airflow db check

# Port-forward para UI
kubectl port-forward -n airflow-dev svc/airflow-dev-api-server 8080:8080 &

# Abrir no browser
open http://localhost:8080
```

## Upgrade do Airflow

### Atualizar Configuração

```bash
# Editar values
vim helm/airflow-values-dev.yaml

# Fazer upgrade
helm upgrade airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
  --values helm/airflow-values-dev.yaml \
  --version 1.17.0 \
  --timeout 10m \
  --wait

# Ver histórico
helm history airflow-dev -n airflow-dev
```

### Atualizar Versão do Chart

```bash
# Ver versões disponíveis
helm search repo apache-airflow/airflow --versions

# Upgrade para nova versão
helm upgrade airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
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
helm upgrade airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
  --values helm/airflow-values-dev.yaml \
  --reuse-values \
  --set defaultAirflowTag=v2.0.0 \
  --wait
```

## Rollback

Se algo der errado:

```bash
# Ver histórico
helm history airflow-dev -n airflow-dev

# Rollback para revisão anterior
helm rollback airflow-dev -n airflow-dev

# Ou rollback para revisão específica
helm rollback airflow-dev 1 -n airflow-dev
```

## Migração de DAGs

### Opção 1: Migrar PVC Existente

Se tem dados no PVC `mmjc-airflow-dags-dev`:

```bash
# 1. Backup do PVC atual no IKS
kubectl exec -it -n airflow-dev POD_NAME -- tar czf - /opt/airflow/dags > /tmp/dags-backup.tar.gz

# 2. Criar PVC no EKS
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mmjc-airflow-dags-dev
  namespace: airflow-dev
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
  -n airflow-dev
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
kubectl describe pod POD_NAME -n airflow-dev

# Ver eventos
kubectl get events -n airflow-dev --sort-by='.lastTimestamp'

# Deletar e recriar
helm uninstall airflow-dev -n airflow-dev
helm install airflow-dev apache-airflow/airflow \
  --namespace airflow-dev \
  --values helm/airflow-values-dev.yaml
```

### Erro de conexão com RDS

```bash
# Testar conectividade
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -n airflow-dev -- \
  psql -h RDS_ENDPOINT -U airflow_admin -d airflow

# Verificar secret
kubectl get secret airflow-postgres-connection-dev -n airflow-dev -o jsonpath='{.data.connection}' | base64 -d
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
helm uninstall airflow-dev -n airflow-dev

# Deletar PVCs (cuidado com dados!)
kubectl delete pvc --all -n airflow-dev

# Deletar namespace
kubectl delete namespace airflow-dev
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
