# Instalação do Milvus via Helm Chart Oficial

Este guia mostra como instalar o Milvus no AWS EKS usando o **Helm Chart oficial**, replicando a configuração atual do `mmjc-test`.

## Visão Geral

**Configuração atual (IBM IKS - mmjc-test)**:
- Chart: `milvus-4.2.57`
- Versão Milvus: `2.5.15`
- Release name: `milvus-mmjc-test`
- Namespace: `mmjc-test`
- Modo: Cluster
- Componentes:
  - MixCoordinator (1)
  - DataNode (2)
  - IndexNode (2)
  - QueryNode (3)
  - Proxy (1)
  - Etcd (3)
  - Kafka (3)
  - MinIO (4)

## Pré-requisitos

### 1. Adicionar Repositório do Milvus

```bash
# Adicionar repositório oficial
helm repo add milvus https://zilliztech.github.io/milvus-helm/

# Atualizar repositórios
helm repo update

# Verificar versões disponíveis
helm search repo milvus/milvus --versions | head -10
```

### 2. Infraestrutura AWS

- [ ] Namespace `mmjc-test` criado no EKS
- [ ] Storage Class `gp3` disponível
- [ ] (Opcional) S3 Bucket para dados (alternativa ao MinIO)
- [ ] (Opcional) IAM Role para Service Account (se usar S3)

## Instalação Passo a Passo

### Etapa 1: Criar Namespace

```bash
kubectl create namespace mmjc-test

# Ou com labels
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: mmjc-test
  labels:
    name: mmjc-test
    environment: dev
    app: milvus
EOF
```

### Etapa 2: Verificar Storage Class

```bash
# Verificar se gp3 existe
kubectl get storageclass gp3

# Se não existe, criar:
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

### Etapa 3: (Opcional) Configurar S3 em vez de MinIO

Se quiser usar S3 nativo em vez de MinIO:

```bash
# Criar bucket S3
aws s3 mb s3://milvus-mmjc-test-data --region us-east-1

# Criar IAM policy
cat > /tmp/milvus-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::milvus-mmjc-test-data",
        "arn:aws:s3:::milvus-mmjc-test-data/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name MilvusS3Access \
  --policy-document file:///tmp/milvus-s3-policy.json

# Criar IAM role com IRSA
# Ver: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
```

### Etapa 4: Configurar values.yaml

```bash
# Copiar template
cp helm/milvus-values-aws-eks.yaml helm/milvus-values-dev.yaml

# Editar se necessário
vim helm/milvus-values-dev.yaml
```

**Principais configurações**:

```yaml
# Já pré-configurado no template:
- storageClass: gp3 (para Etcd, Kafka, MinIO)
- replicas: mesmos números do IKS
- resources: mesmos limites do IKS
- nodeSelector/tolerations: removidos (específicos do IBM)
```

### Etapa 5: Instalar via Helm

```bash
# Dry-run primeiro
helm install milvus-mmjc-test milvus/milvus \
  --namespace mmjc-test \
  --values helm/milvus-values-dev.yaml \
  --version 4.2.57 \
  --dry-run --debug > /tmp/milvus-dry-run.yaml

# Revisar
less /tmp/milvus-dry-run.yaml

# Instalar
helm install milvus-mmjc-test milvus/milvus \
  --namespace mmjc-test \
  --values helm/milvus-values-dev.yaml \
  --version 4.2.57 \
  --timeout 15m \
  --wait

# Output esperado:
# NAME: milvus-mmjc-test
# NAMESPACE: mmjc-test
# STATUS: deployed
```

### Etapa 6: Monitorar Instalação

```bash
# Ver status
helm status milvus-mmjc-test -n mmjc-test

# Monitorar pods (StatefulSets demoram mais)
kubectl get pods -n mmjc-test -w

# Ver StatefulSets
kubectl get statefulset -n mmjc-test

# Esperado:
# milvus-mmjc-test-etcd       3/3
# milvus-mmjc-test-kafka      3/3
# milvus-mmjc-test-minio      4/4

# Ver logs
kubectl logs -n mmjc-test -l component=proxy -f
```

### Etapa 7: Validar Instalação

```bash
# Todos os pods devem estar Running
kubectl get pods -n mmjc-test | grep milvus

# Esperado (total ~17 pods):
# milvus-mmjc-test-datanode-xxx         1/1     Running
# milvus-mmjc-test-datanode-xxx         1/1     Running
# milvus-mmjc-test-indexnode-xxx        1/1     Running
# milvus-mmjc-test-indexnode-xxx        1/1     Running
# milvus-mmjc-test-querynode-xxx        1/1     Running
# milvus-mmjc-test-querynode-xxx        1/1     Running
# milvus-mmjc-test-querynode-xxx        1/1     Running
# milvus-mmjc-test-mixcoord-xxx         1/1     Running
# milvus-mmjc-test-proxy-xxx            1/1     Running
# milvus-mmjc-test-etcd-0               1/1     Running
# milvus-mmjc-test-etcd-1               1/1     Running
# milvus-mmjc-test-etcd-2               1/1     Running
# milvus-mmjc-test-kafka-0              1/1     Running
# milvus-mmjc-test-kafka-1              1/1     Running
# milvus-mmjc-test-kafka-2              1/1     Running
# milvus-mmjc-test-minio-0              1/1     Running
# milvus-mmjc-test-minio-1              1/1     Running
# milvus-mmjc-test-minio-2              1/1     Running
# milvus-mmjc-test-minio-3              1/1     Running

# Testar API
kubectl port-forward -n mmjc-test svc/milvus-mmjc-test-proxy 19530:19530 &

python3 <<EOF
from pymilvus import connections, utility

connections.connect(host='localhost', port='19530')
print(f"Milvus version: {utility.get_server_version()}")
print(f"Collections: {utility.list_collections()}")
EOF
```

### Etapa 8: (Opcional) Instalar Attu UI

```bash
# Attu não vem no chart do Milvus, instalar separadamente
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: attu
  namespace: mmjc-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: attu
  template:
    metadata:
      labels:
        app: attu
    spec:
      containers:
      - name: attu
        image: zilliz/attu:v2.5
        ports:
        - containerPort: 3000
        env:
        - name: MILVUS_URL
          value: "milvus-mmjc-test-proxy:19530"
---
apiVersion: v1
kind: Service
metadata:
  name: attu
  namespace: mmjc-test
spec:
  selector:
    app: attu
  ports:
  - port: 80
    targetPort: 3000
EOF

# Port-forward para acessar
kubectl port-forward -n mmjc-test svc/attu 8000:80 &
open http://localhost:8000
```

## Migração de Dados

### Opção 1: Backup e Restore via Milvus Backup Tool

```bash
# No IKS - Fazer backup
# Instalar milvus-backup: https://milvus.io/docs/milvus_backup_overview.md

# Configurar backup.yaml
cat > backup.yaml <<EOF
milvus:
  address: milvus-mmjc-test-proxy
  port: 19530
minio:
  address: milvus-mmjc-test-minio
  port: 9000
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
  useSSL: false
  bucketName: milvus-bucket
EOF

# Criar backup
./milvus-backup backup -n my_backup -c backup.yaml

# No EKS - Restaurar
# Copiar dados de backup para novo MinIO/S3
# Restaurar
./milvus-backup restore -n my_backup -s my_restore -c backup.yaml
```

### Opção 2: Export/Import de Collections

```bash
# Para cada collection, fazer export/import manual
# Ver script em: scripts/milvus-export-import.py
```

## Upgrade

```bash
# Ver versões disponíveis
helm search repo milvus/milvus --versions

# Upgrade
helm upgrade milvus-mmjc-test milvus/milvus \
  --namespace mmjc-test \
  --values helm/milvus-values-dev.yaml \
  --version 4.2.58 \
  --timeout 15m \
  --wait

# Ver histórico
helm history milvus-mmjc-test -n mmjc-test
```

## Rollback

```bash
# Rollback para revisão anterior
helm rollback milvus-mmjc-test -n mmjc-test

# Ou para revisão específica
helm rollback milvus-mmjc-test 1 -n mmjc-test
```

## Troubleshooting

### Pods não inicializam

```bash
# Ver logs de cada componente
kubectl logs -n mmjc-test milvus-mmjc-test-etcd-0
kubectl logs -n mmjc-test milvus-mmjc-test-kafka-0

# Ver eventos
kubectl get events -n mmjc-test --sort-by='.lastTimestamp'
```

### Etcd cluster não forma quorum

```bash
# Verificar PVCs
kubectl get pvc -n mmjc-test | grep etcd

# Verificar network
kubectl exec -it -n mmjc-test milvus-mmjc-test-etcd-0 -- \
  nslookup milvus-mmjc-test-etcd-1.milvus-mmjc-test-etcd
```

### Kafka não conecta ao Zookeeper

```bash
# Verificar Zookeeper (criado pelo Kafka subchart)
kubectl get pods -n mmjc-test | grep zookeeper

# Ver logs
kubectl logs -n mmjc-test milvus-mmjc-test-kafka-0
```

### Storage não faz bind

```bash
# Verificar storage class
kubectl get sc gp3 -o yaml

# Verificar EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

## Desinstalação

```bash
# Desinstalar Milvus
helm uninstall milvus-mmjc-test -n mmjc-test

# Deletar PVCs (CUIDADO: perda de dados!)
kubectl delete pvc -l app.kubernetes.io/instance=milvus-mmjc-test -n mmjc-test

# Deletar namespace
kubectl delete namespace mmjc-test
```

## Comparação IKS vs EKS

| Componente | IKS (IBM) | EKS (AWS) |
|------------|-----------|-----------|
| **Storage Class** | ibmc-block-gold | gp3 |
| **Node Selector** | worker-pool-name: milvus-pool | Remover ou adaptar |
| **Tolerations** | reserved=milvus | Remover ou adaptar |
| **MinIO** | 4 réplicas PVC | Mesmo, ou usar S3 |
| **Etcd** | 3 réplicas PVC | Mesmo |
| **Kafka** | 3 réplicas PVC | Mesmo |
| **Réplicas** | Manter mesmos números | ✓ |
| **Recursos** | Manter mesmos limites | ✓ |

## Referências

- [Milvus Helm Chart](https://github.com/zilliztech/milvus-helm)
- [Milvus Documentation](https://milvus.io/docs/)
- [Milvus Backup Tool](https://milvus.io/docs/milvus_backup_overview.md)

## Próximos Passos

1. Instalar Milvus
2. Validar conectividade
3. Migrar dados (se necessário)
4. Instalar Attu UI
5. Configurar outros componentes (mcp-milvus-db, etc)
6. Validar aplicações que usam Milvus
