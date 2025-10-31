# Migração do Milvus

Este documento detalha o processo de migração do Milvus Dev do IBM IKS para AWS EKS.

## Visão Geral

O namespace `milvus-dev` (ou componentes do `mmjc-test`) contém:
- **StatefulSets**: Etcd (3), Kafka (3), Zookeeper (3), MinIO (4)
- **Deployments**: Milvus DataNode (2), IndexNode (1), QueryNode (1), MixCoord (1), Proxy (1), Attu UI, MCP Milvus DB
- **Storage**: PersistentVolumeClaims para cada StatefulSet

## Pré-requisitos

Antes de iniciar esta migração:

- [ ] Infraestrutura AWS criada via Terraform
- [ ] Namespace `milvus-dev` criado no EKS
- [ ] Imagens Docker migradas para registry alvo
- [ ] kubectl configurado para cluster EKS
- [ ] Decisão sobre MinIO vs S3 nativo

## Componentes do Milvus

### StatefulSets

| Componente | Réplicas | Storage | Função |
|------------|----------|---------|--------|
| Etcd | 3 | 10Gi cada | Metadata store |
| Kafka | 3 | 50Gi cada | Message queue |
| Zookeeper | 3 | 10Gi cada | Kafka coordination |
| MinIO | 4 | 100Gi cada | Object storage |

### Deployments

| Componente | Réplicas | Função |
|------------|----------|--------|
| DataNode | 2 | Persiste dados |
| IndexNode | 1 | Cria índices |
| QueryNode | 1 | Processa queries |
| MixCoord | 1 | Coordenação |
| Proxy | 1 | Gateway API |
| Attu | 1 | UI de administração |
| MCP Milvus DB | 1 | MCP server |

## Estratégia de Migração

### Abordagem: Fresh Install + Data Migration

1. **Deploy Infrastructure**: Etcd, Kafka, Zookeeper, MinIO
2. **Deploy Milvus**: Componentes do Milvus
3. **Migrate Data**: Se necessário, migrar collections existentes
4. **Validate**: Verificar funcionamento

**Nota**: Se não precisa dos dados existentes, pode fazer fresh install sem migração de dados.

## Passo a Passo

### Etapa 1: Decisão sobre Storage Backend

#### Opção A: Manter MinIO Interno (Recomendado para Dev)

**Vantagens**:
- Simples de configurar
- Não depende de serviços AWS externos
- Isolamento completo

**Desvantagens**:
- Usa PVCs (EBS)
- Mais recursos no cluster

#### Opção B: Usar S3 Nativo (Recomendado para Prod)

**Vantagens**:
- Managed pela AWS
- Escalabilidade ilimitada
- Backup automático

**Desvantagens**:
- Custos de S3
- Dependência externa

### Etapa 2: Deploy da Infraestrutura

#### 2.1. Deploy Etcd

```bash
# Aplicar manifests
kubectl apply -k kustomize/milvus/etcd/

# Aguardar todos os pods
kubectl wait --for=condition=ready pod -l app=etcd -n milvus-dev --timeout=600s

# Verificar
kubectl get pods -n milvus-dev -l app=etcd
# Esperado: 3 pods Running
```

#### 2.2. Deploy Zookeeper

```bash
kubectl apply -k kustomize/milvus/zookeeper/

kubectl wait --for=condition=ready pod -l app=zookeeper -n milvus-dev --timeout=600s

kubectl get pods -n milvus-dev -l app=zookeeper
# Esperado: 3 pods Running
```

#### 2.3. Deploy Kafka

```bash
kubectl apply -k kustomize/milvus/kafka/

kubectl wait --for=condition=ready pod -l app=kafka -n milvus-dev --timeout=600s

kubectl get pods -n milvus-dev -l app=kafka
# Esperado: 3 pods Running
```

#### 2.4. Deploy MinIO (ou configurar S3)

**Se usar MinIO**:

```bash
kubectl apply -k kustomize/milvus/minio/

kubectl wait --for=condition=ready pod -l app=minio -n milvus-dev --timeout=600s

kubectl get pods -n milvus-dev -l app=minio
# Esperado: 4 pods Running
```

**Se usar S3**:

Criar secret com credenciais ou usar IRSA:

```bash
# Usando IRSA (recomendado)
# Já configurado no Terraform com IAM role

# Ou criar secret (não recomendado)
kubectl create secret generic milvus-s3-secret \
  --from-literal=accesskey=AKIA... \
  --from-literal=secretkey=... \
  -n milvus-dev
```

### Etapa 3: Deploy dos Componentes Milvus

#### 3.1. Aplicar Configuração

```bash
cd kustomize/milvus

# Verificar configuração
cat kustomization.yaml
```

#### 3.2. Aplicar Manifests

```bash
# Deploy completo
kubectl apply -k kustomize/milvus/

# Ou via script
./migrate.sh --component milvus
```

#### 3.3. Aguardar Pods

```bash
# Monitorar todos os pods
kubectl get pods -n milvus-dev -w

# Aguardar specific components
kubectl wait --for=condition=ready pod -l component=datanode -n milvus-dev --timeout=600s
kubectl wait --for=condition=ready pod -l component=querynode -n milvus-dev --timeout=600s
```

### Etapa 4: Validar Deployment

#### 4.1. Verificar Status

```bash
# Todos os pods
kubectl get pods -n milvus-dev

# Esperado:
# milvus-mmjc-test-etcd-0            1/1     Running
# milvus-mmjc-test-etcd-1            1/1     Running
# milvus-mmjc-test-etcd-2            1/1     Running
# milvus-mmjc-test-kafka-0           1/1     Running
# milvus-mmjc-test-kafka-1           1/1     Running
# milvus-mmjc-test-kafka-2           1/1     Running
# milvus-mmjc-test-zookeeper-0       1/1     Running
# milvus-mmjc-test-zookeeper-1       1/1     Running
# milvus-mmjc-test-zookeeper-2       1/1     Running
# milvus-mmjc-test-minio-0           1/1     Running
# milvus-mmjc-test-minio-1           1/1     Running
# milvus-mmjc-test-minio-2           1/1     Running
# milvus-mmjc-test-minio-3           1/1     Running
# milvus-mmjc-test-datanode-xxx      1/1     Running
# milvus-mmjc-test-indexnode-xxx     1/1     Running
# milvus-mmjc-test-querynode-xxx     1/1     Running
# milvus-mmjc-test-mixcoord-xxx      1/1     Running
# milvus-mmjc-test-proxy-xxx         1/1     Running
# my-attu-xxx                       1/1     Running
```

#### 4.2. Verificar PVCs

```bash
# Listar PVCs
kubectl get pvc -n milvus-dev

# Todos devem estar Bound
```

#### 4.3. Verificar Services

```bash
kubectl get svc -n milvus-dev

# Serviços importantes:
# milvus-mmjc-test-proxy (porta 19530) - API do Milvus
# my-attu (porta 80) - UI
```

### Etapa 5: Testar Conectividade

#### 5.1. Port-forward para Attu UI

```bash
kubectl port-forward -n milvus-dev svc/my-attu 8000:80 &

# Abrir no browser
open http://localhost:8000
```

#### 5.2. Testar API do Milvus

```bash
# Port-forward para API
kubectl port-forward -n milvus-dev svc/milvus-mmjc-test-proxy 19530:19530 &

# Testar com Python (exemplo)
python3 << EOF
from pymilvus import connections, utility

connections.connect(host='localhost', port='19530')
print("Milvus version:", utility.get_server_version())
print("Collections:", utility.list_collections())
EOF
```

### Etapa 6: Migrar Dados (Se Necessário)

#### 6.1. Export do IKS

Se precisar migrar collections existentes:

```bash
# Conectar ao IKS
ibmcloud ks cluster config --cluster mjc-cluster

# Port-forward para Milvus no IKS
kubectl port-forward -n mmjc-test svc/milvus-proxy 19530:19530 &

# Export collections (Python)
python3 << EOF
from pymilvus import connections, Collection, utility
import json

connections.connect(host='localhost', port='19530')

collections = utility.list_collections()
for coll_name in collections:
    coll = Collection(coll_name)
    # Export logic here - salvar em arquivo ou S3
    print(f"Exporting {coll_name}...")
EOF
```

#### 6.2. Import no EKS

```bash
# Conectar ao EKS
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# Port-forward para Milvus no EKS
kubectl port-forward -n milvus-dev svc/milvus-mmjc-test-proxy 19530:19530 &

# Import collections
python3 << EOF
from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType
import json

connections.connect(host='localhost', port='19530')

# Import logic here - carregar de arquivo ou S3
print("Importing collections...")
EOF
```

### Etapa 7: Configurar Ingress (Opcional)

Se precisar expor Milvus externamente:

```yaml
# ingress-milvus.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: milvus-ingress
  namespace: milvus-dev
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: milvus.internal.seu-dominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: milvus-mmjc-test-proxy
            port:
              number: 19530
```

```bash
kubectl apply -f ingress-milvus.yaml
```

## Troubleshooting

### Pods não inicializam

```bash
# Ver logs de pods específicos
kubectl logs -n milvus-dev milvus-mmjc-test-etcd-0
kubectl logs -n milvus-dev milvus-mmjc-test-datanode-xxx

# Ver eventos
kubectl get events -n milvus-dev --sort-by='.lastTimestamp'
```

### PVCs não fazem bind

```bash
# Verificar storage class
kubectl get sc

# Deve ter gp3 disponível
# Se não, criar:
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
EOF
```

### Erro de conexão entre componentes

```bash
# Verificar DNS interno
kubectl run -it --rm debug --image=busybox --restart=Never -n milvus-dev -- \
  nslookup milvus-mmjc-test-etcd

# Verificar network policies
kubectl get networkpolicies -n milvus-dev
```

## Checklist de Validação

- [ ] Todos os StatefulSets têm réplicas esperadas Running
- [ ] Todos os Deployments estão Running
- [ ] PVCs estão Bound
- [ ] Etcd cluster está saudável (3/3 pods)
- [ ] Kafka cluster está saudável (3/3 pods)
- [ ] MinIO está acessível (ou S3 configurado)
- [ ] Attu UI acessível e mostra cluster
- [ ] API do Milvus responde
- [ ] Collections visíveis (se migrou dados)

## Próximos Passos

Após migrar o Milvus, prossiga para:
1. [06-oauth-setup.md](06-oauth-setup.md) - Configurar autenticação
2. [07-validacao.md](07-validacao.md) - Validar toda a migração
