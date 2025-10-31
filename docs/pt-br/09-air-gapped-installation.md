# Instalação em Ambiente Air-gapped

Este guia detalha a instalação do Airflow e Milvus em ambientes air-gapped (sem acesso à internet) usando Artifactory como registry interno.

## Visão Geral

Em ambientes air-gapped:
- ❌ Sem acesso direto a registries públicos (Docker Hub, ICR, GCR, Quay)
- ❌ Sem acesso direto a repositórios Git públicos
- ✅ Uso obrigatório de Artifactory como proxy/cache de imagens
- ✅ Helm charts devem ser baixados e transferidos manualmente

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                  Internet (Zona Pública)                    │
│                                                             │
│  • docker.io                                                │
│  • icr.io                                                   │
│  • gcr.io                                                   │
│  • quay.io                                                  │
│  • github.com                                               │
└─────────────────────────────────────────────────────────────┘
                            ↓ (Firewall)
                     [Bastion Host]
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Artifactory (Zona Interna)                     │
│                                                             │
│  docker-arc3-remote.artifactory.prod.aws.cloud.ihf          │
│                                                             │
│  • docker-hub-remote (proxy → docker.io)                    │
│  • ibm-icr-remote (proxy → icr.io)                          │
│  • gcr-remote (proxy → gcr.io)                              │
│  • quay-remote (proxy → quay.io)                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  AWS EKS Cluster (Air-gapped)               │
│                                                             │
│  • Pods pull images from Artifactory only                   │
│  • No direct internet access                                │
└─────────────────────────────────────────────────────────────┘
```

## Mapeamento de Registries

### Configuração

Veja: [config/registry-mapping.yaml](../../config/registry-mapping.yaml)

### Exemplos de Mapeamento

| Imagem Original | Imagem no Artifactory |
|-----------------|----------------------|
| `icr.io/mjc-cr/mmjc-airflow-service:latest` | `docker-arc3-remote.artifactory.prod.aws.cloud.ihf/mmjc-airflow-service:latest` |
| `br.icr.io/br-ibm-images/understanding-agent-arc:1.5.5` | `docker-arc3-remote.artifactory.prod.aws.cloud.ihf/understanding-agent-arc:1.5.5` |
| `milvusdb/milvus:v2.5.15` | `docker-arc3-remote.artifactory.prod.aws.cloud.ihf/milvusdb/milvus:v2.5.15` |
| `docker.io/bitnami/kafka:3.1.0-debian-10-r52` | `docker-arc3-remote.artifactory.prod.aws.cloud.ihf/bitnami/kafka:3.1.0-debian-10-r52` |
| `quay.io/prometheus/statsd-exporter:v0.28.0` | `docker-arc3-remote.artifactory.prod.aws.cloud.ihf/prometheus/statsd-exporter:v0.28.0` |

## Pré-requisitos

### 1. Acesso ao Artifactory

```bash
# Credenciais necessárias
ARTIFACTORY_URL="docker-arc3-remote.artifactory.prod.aws.cloud.ihf"
ARTIFACTORY_USER="seu-usuario"
ARTIFACTORY_PASSWORD="seu-token-ou-senha"
```

### 2. Bastion Host (com acesso à internet)

Você precisa de uma máquina com:
- ✅ Acesso à internet (para pull de imagens)
- ✅ Acesso ao Artifactory (para push de imagens)
- ✅ Docker instalado

## Instalação Passo a Passo

### Etapa 1: Espelhar Imagens para Artifactory

#### 1.1. No Bastion Host

```bash
# Clonar repositório
git clone <repo-url>
cd mjc_install-

# Configurar credenciais
export ARTIFACTORY_USER="seu-usuario"
export ARTIFACTORY_PASSWORD="seu-token"

# Executar script de mirror
chmod +x scripts/mirror-images-to-artifactory.sh
./scripts/mirror-images-to-artifactory.sh
```

Este script irá:
1. Pull de todas as imagens dos registries públicos
2. Tag com o registry Artifactory
3. Push para Artifactory
4. Gerar Helm values atualizados

#### 1.2. Verificar Imagens no Artifactory

```bash
# Login no Artifactory
docker login docker-arc3-remote.artifactory.prod.aws.cloud.ihf

# Listar imagens (via Artifactory UI ou API)
curl -u $ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD \
  https://artifactory.prod.aws.cloud.ihf/api/docker/docker-arc3-remote/v2/_catalog
```

### Etapa 2: Transferir Helm Charts

#### 2.1. Baixar Helm Charts (Bastion Host)

```bash
# Adicionar repositórios
helm repo add apache-airflow https://airflow.apache.org
helm repo add milvus https://zilliztech.github.io/milvus-helm/
helm repo update

# Baixar charts
mkdir -p helm-charts
cd helm-charts

helm pull apache-airflow/airflow --version 1.17.0
helm pull milvus/milvus --version 4.2.57

# Verificar
ls -lh
# airflow-1.17.0.tgz
# milvus-4.2.57.tgz
```

#### 2.2. Transferir para Ambiente Air-gapped

```bash
# Criar pacote
tar czf helm-charts-and-values.tar.gz \
  helm-charts/ \
  helm/airflow-values-artifactory.yaml \
  helm/milvus-values-artifactory.yaml \
  config/registry-mapping.yaml

# Transferir via método seguro:
# - SCP
# - SFTP
# - Storage físico
# - Processo interno de transferência de arquivos
```

### Etapa 3: Criar Registry Secret no Kubernetes

No cluster EKS air-gapped:

```bash
# Criar secret para Artifactory
kubectl create secret docker-registry artifactory-registry-secret \
  --docker-server=docker-arc3-remote.artifactory.prod.aws.cloud.ihf \
  --docker-username=$ARTIFACTORY_USER \
  --docker-password=$ARTIFACTORY_PASSWORD \
  --namespace=airflow-test

kubectl create secret docker-registry artifactory-registry-secret \
  --docker-server=docker-arc3-remote.artifactory.prod.aws.cloud.ihf \
  --docker-username=$ARTIFACTORY_USER \
  --docker-password=$ARTIFACTORY_PASSWORD \
  --namespace=mmjc-test
```

### Etapa 4: Instalar Airflow

```bash
# Extrair charts
tar xzf helm-charts-and-values.tar.gz

# Criar namespace
kubectl create namespace airflow-test

# Instalar a partir do chart local
helm install airflow-test helm-charts/airflow-1.17.0.tgz \
  --namespace airflow-test \
  --values helm/airflow-values-artifactory.yaml \
  --timeout 10m \
  --wait
```

### Etapa 5: Instalar Milvus

```bash
# Criar namespace
kubectl create namespace mmjc-test

# Instalar a partir do chart local
helm install milvus-mmjc-test helm-charts/milvus-4.2.57.tgz \
  --namespace mmjc-test \
  --values helm/milvus-values-artifactory.yaml \
  --timeout 15m \
  --wait
```

### Etapa 6: Validar

```bash
# Verificar pods
kubectl get pods -n airflow-test
kubectl get pods -n mmjc-test

# Verificar se imagens foram puxadas do Artifactory
kubectl describe pod -n airflow-test <pod-name> | grep "Image:"
kubectl describe pod -n mmjc-test <pod-name> | grep "Image:"

# Deve mostrar: docker-arc3-remote.artifactory.prod.aws.cloud.ihf/...
```

## Atualização de Imagens

### Quando uma nova imagem é necessária:

#### 1. No Bastion Host

```bash
# Pull da nova imagem
docker pull icr.io/mjc-cr/mmjc-airflow-service:v2.0.0

# Tag para Artifactory
docker tag icr.io/mjc-cr/mmjc-airflow-service:v2.0.0 \
  docker-arc3-remote.artifactory.prod.aws.cloud.ihf/mmjc-airflow-service:v2.0.0

# Push para Artifactory
docker push docker-arc3-remote.artifactory.prod.aws.cloud.ihf/mmjc-airflow-service:v2.0.0
```

#### 2. No Cluster Air-gapped

```bash
# Atualizar Helm release
helm upgrade airflow-test helm-charts/airflow-1.17.0.tgz \
  --namespace airflow-test \
  --set defaultAirflowTag=v2.0.0 \
  --reuse-values \
  --wait
```

## Troubleshooting

### Erro: ImagePullBackOff

```bash
# Verificar logs
kubectl describe pod <pod-name> -n <namespace>

# Verificar eventos
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Possíveis causas:
# 1. Imagem não existe no Artifactory
# 2. Secret do registry não configurado
# 3. Nome da imagem incorreto
```

**Solução**:

```bash
# 1. Verificar se imagem existe no Artifactory
curl -u $USER:$PASS https://artifactory.../api/docker/.../v2/<image>/tags/list

# 2. Verificar secret
kubectl get secret artifactory-registry-secret -n <namespace> -o yaml

# 3. Verificar nome da imagem no pod
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].image}'
```

### Erro: Authentication Failed

```bash
# Recriar secret com credenciais corretas
kubectl delete secret artifactory-registry-secret -n <namespace>

kubectl create secret docker-registry artifactory-registry-secret \
  --docker-server=docker-arc3-remote.artifactory.prod.aws.cloud.ihf \
  --docker-username=$NEW_USER \
  --docker-password=$NEW_PASS \
  --namespace=<namespace>

# Restart pods
kubectl rollout restart deployment -n <namespace>
```

### Erro: Tag not found

```bash
# Listar tags disponíveis no Artifactory
curl -u $USER:$PASS \
  https://artifactory.../api/docker/docker-arc3-remote/v2/<image>/tags/list

# Mirror a tag correta
docker pull source-registry/image:correct-tag
docker tag source-registry/image:correct-tag artifactory.../image:correct-tag
docker push artifactory.../image:correct-tag
```

## Script Helper

### Listar Imagens Atuais no Cluster

```bash
# Criar script
cat > scripts/list-cluster-images.sh <<'EOF'
#!/bin/bash
echo "=== Airflow Images ==="
kubectl get pods -n airflow-test -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

echo ""
echo "=== Milvus Images ==="
kubectl get pods -n mmjc-test -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
EOF

chmod +x scripts/list-cluster-images.sh
./scripts/list-cluster-images.sh
```

### Verificar se Imagem Existe no Artifactory

```bash
# Criar função helper
check_image_in_artifactory() {
    local image="$1"
    local tag="${2:-latest}"

    curl -u $ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD \
      "https://artifactory.prod.aws.cloud.ihf/api/docker/docker-arc3-remote/v2/${image}/manifests/${tag}" \
      -s -o /dev/null -w "%{http_code}"
}

# Usar
if [ "$(check_image_in_artifactory "mmjc-airflow-service" "latest")" = "200" ]; then
    echo "✓ Image exists"
else
    echo "✗ Image not found"
fi
```

## Checklist de Instalação Air-gapped

### Preparação (Bastion Host)
- [ ] Docker instalado
- [ ] Acesso à internet
- [ ] Acesso ao Artifactory
- [ ] Credenciais do Artifactory configuradas
- [ ] Repositório clonado

### Mirror de Imagens
- [ ] Script `mirror-images-to-artifactory.sh` executado
- [ ] Todas as imagens do Airflow espelhadas
- [ ] Todas as imagens do Milvus espelhadas
- [ ] Imagens customizadas espelhadas
- [ ] Imagens verificadas no Artifactory UI

### Helm Charts
- [ ] Charts baixados (airflow-1.17.0.tgz, milvus-4.2.57.tgz)
- [ ] Values gerados (airflow-values-artifactory.yaml, milvus-values-artifactory.yaml)
- [ ] Pacote criado e transferido

### Cluster EKS (Air-gapped)
- [ ] Namespaces criados
- [ ] Registry secrets criados
- [ ] Charts extraídos
- [ ] Airflow instalado
- [ ] Milvus instalado
- [ ] Pods Running
- [ ] Imagens puxadas do Artifactory (verificado)

## Referências

- [Artifactory Docker Registry](https://jfrog.com/help/r/jfrog-artifactory-documentation/docker-registry)
- [Helm Chart Repository](https://helm.sh/docs/topics/chart_repository/)
- [Kubernetes ImagePullSecrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)

## Próximos Passos

Após instalação em ambiente air-gapped:
1. Configurar monitoramento
2. Configurar backups
3. Documentar processo de atualização
4. Treinar equipe em procedimentos air-gapped
