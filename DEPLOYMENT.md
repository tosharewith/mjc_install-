# 🚀 Guia de Deployment

## 📦 Código-Fonte

### Repositório GitHub
**URL**: https://github.com/tosharewith/mjc_install

### Clonar Repositório
```bash
git clone https://github.com/tosharewith/mjc_install.git
cd mjc_install
```

## 🐳 Imagens de Container

### Imagens Identificadas

As seguintes imagens precisam ser migradas:

| Imagem Original | Componente |
|----------------|------------|
| `icr.io/mjc-cr/mmjc-airflow-service:latest` | Airflow (todos componentes) |
| `quay.io/prometheus/statsd-exporter:v0.28.0` | StatsD Exporter (público) |

### Opções de Migração

#### Opção 1: Migrar para AWS ECR

```bash
# 1. Configurar target registry
vim config/migration.env
# Adicionar: TARGET_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com

# 2. Executar migração
./scripts/migrate-container-images.sh
```

#### Opção 2: Migrar para IBM ICR (conta Itaú)

```bash
# 1. Login na conta Itaú
~/ibm-login-itau

# 2. Criar namespace no ICR
ibmcloud cr namespace-add itau-airflow

# 3. Configurar target registry
vim config/migration.env
# Adicionar: TARGET_REGISTRY=icr.io/itau-airflow

# 4. Executar migração
./scripts/migrate-container-images.sh
```

#### Opção 3: Usar Registries Originais (Temporário)

Para testes rápidos, você pode usar as imagens originais:
- `icr.io/mjc-cr/*` requer acesso à conta original
- `quay.io/*` são públicas

**⚠️ Não recomendado para produção**

### Migração Manual de Uma Imagem

```bash
# Usando Docker
docker pull icr.io/mjc-cr/mmjc-airflow-service:latest
docker tag icr.io/mjc-cr/mmjc-airflow-service:latest \
    NOVO_REGISTRY/mmjc-airflow-service:latest
docker push NOVO_REGISTRY/mmjc-airflow-service:latest

# Usando Skopeo (recomendado - mais rápido)
skopeo copy \
    docker://icr.io/mjc-cr/mmjc-airflow-service:latest \
    docker://NOVO_REGISTRY/mmjc-airflow-service:latest
```

### Instalar Skopeo (Opcional mas Recomendado)

```bash
# macOS
brew install skopeo

# Linux (Ubuntu/Debian)
sudo apt-get install skopeo

# Linux (RHEL/CentOS)
sudo yum install skopeo
```

## 🔄 Atualizar Referências de Imagens

Após migrar as imagens, atualize os manifestos:

### 1. Kustomize

```bash
# Editar kustomize/airflow-test/kustomization.yaml
vim kustomize/airflow-test/kustomization.yaml
```

Adicionar seção de imagens:

```yaml
images:
  - name: icr.io/mjc-cr/mmjc-airflow-service
    newName: NOVO_REGISTRY/mmjc-airflow-service
    newTag: latest
  - name: quay.io/prometheus/statsd-exporter
    newName: NOVO_REGISTRY/statsd-exporter
    newTag: v0.28.0
```

### 2. Terraform

Se usando imagens no Terraform, atualizar:

```terraform
# terraform/environments/dev/main.tf
# Adicionar variável
variable "container_registry" {
  description = "Container registry URL"
  default     = "NOVO_REGISTRY"
}
```

## 🧪 Testar Acesso às Imagens

```bash
# Testar pull do novo registry
docker pull NOVO_REGISTRY/mmjc-airflow-service:latest

# Verificar tamanho
docker images | grep mmjc-airflow-service

# Testar run
docker run --rm NOVO_REGISTRY/mmjc-airflow-service:latest --version
```

## 📋 Checklist de Imagens

- [ ] Identificar todas imagens usadas
  ```bash
  grep -r "image:" kustomize/ | sort -u
  ```

- [ ] Migrar para novo registry
  ```bash
  ./scripts/migrate-container-images.sh
  ```

- [ ] Atualizar manifestos Kustomize
  ```bash
  vim kustomize/airflow-test/kustomization.yaml
  vim kustomize/milvus/kustomization.yaml
  ```

- [ ] Testar pull das novas imagens
  ```bash
  docker pull NOVO_REGISTRY/imagem:tag
  ```

- [ ] Validar deployment
  ```bash
  kubectl apply -k kustomize/airflow-test/ --dry-run=client
  ```

## 🔐 Autenticação de Registries

### AWS ECR

```bash
# Login via AWS CLI
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.us-east-1.amazonaws.com

# Criar secret no Kubernetes (se necessário)
kubectl create secret docker-registry ecr-registry-secret \
    --docker-server=123456789012.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region us-east-1) \
    --namespace=airflow-test
```

### IBM ICR

```bash
# Login via IBM Cloud CLI
ibmcloud cr login

# Criar secret no Kubernetes
kubectl create secret docker-registry icr-registry-secret \
    --docker-server=icr.io \
    --docker-username=iamapikey \
    --docker-password=$(ibmcloud iam api-key-create temp-key --output json | jq -r .apikey) \
    --namespace=airflow-test
```

## 🚢 Deploy Completo

```bash
# 1. Clonar repositório
git clone https://github.com/tosharewith/mjc_install.git
cd mjc_install

# 2. Configurar ambiente
cp config/migration.env.example config/migration.env
vim config/migration.env

# 3. Migrar imagens (escolher opção)
./scripts/migrate-container-images.sh

# 4. Atualizar referências
vim kustomize/airflow-test/kustomization.yaml

# 5. Executar migração
./migrate.sh

# 6. Validar
./scripts/validate-migration.sh
```

## 📝 Notas Importantes

1. **Imagens Públicas**: `quay.io/prometheus/statsd-exporter` pode permanecer no registry público

2. **Imagens Privadas**: `icr.io/mjc-cr/*` DEVEM ser migradas pois estão em conta diferente

3. **Tags**: Sempre use tags específicas (não `latest`) em produção

4. **Scan de Vulnerabilidades**: Execute scan após migrar
   ```bash
   # AWS ECR
   aws ecr start-image-scan --repository-name mmjc-airflow-service \
       --image-id imageTag=latest --region us-east-1

   # IBM ICR
   ibmcloud cr vulnerability-assessment icr.io/namespace/image:tag
   ```

5. **Tamanho**: A imagem do Airflow pode ser grande (~2GB), considere:
   - Multi-stage builds
   - Remover dependências desnecessárias
   - Usar imagens base menores

## 🆘 Troubleshooting

### Erro: "unauthorized: authentication required"

```bash
# Refazer login no registry
aws ecr get-login-password --region us-east-1 | docker login ...
# ou
ibmcloud cr login
```

### Erro: "manifest unknown"

```bash
# Verificar se imagem existe
docker pull IMAGE:TAG
# ou
skopeo inspect docker://IMAGE:TAG
```

### Erro: "no space left on device"

```bash
# Limpar imagens antigas
docker system prune -a

# Verificar espaço
df -h
```

---

**Última atualização**: 2025-10-29
**Repositório**: https://github.com/tosharewith/mjc_install
