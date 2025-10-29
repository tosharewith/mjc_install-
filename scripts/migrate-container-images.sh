#!/bin/bash
#
# Script para migrar imagens de container do IBM ICR para AWS ECR (ou ICR da conta Itaú)
#

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Carregar configuração
if [ -f "../config/migration.env" ]; then
    source ../config/migration.env
fi

log_info "============================================"
log_info "Migração de Imagens de Container"
log_info "============================================"
echo ""

# Lista de imagens identificadas
IMAGES=(
    "icr.io/mjc-cr/mmjc-airflow-service:latest"
    # Adicionar outras imagens conforme necessário
)

# Verificar se skopeo está instalado (recomendado) ou usar docker
if command -v skopeo &> /dev/null; then
    USE_SKOPEO=true
    log_info "Usando skopeo para migração (recomendado)"
elif command -v docker &> /dev/null; then
    USE_SKOPEO=false
    log_warn "Usando docker para migração (mais lento)"
else
    log_error "Nem skopeo nem docker estão instalados"
    exit 1
fi

# Opção 1: Migrar para AWS ECR
if [ "$TARGET_REGISTRY" != "" ] && [[ "$TARGET_REGISTRY" == *"ecr"* ]]; then
    log_info "Target: AWS ECR"

    # Login no ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $TARGET_REGISTRY

    for IMAGE in "${IMAGES[@]}"; do
        # Extrair nome e tag
        IMAGE_NAME=$(echo $IMAGE | cut -d'/' -f3 | cut -d':' -f1)
        IMAGE_TAG=$(echo $IMAGE | cut -d':' -f2)

        TARGET_IMAGE="${TARGET_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

        log_info "Migrando: $IMAGE → $TARGET_IMAGE"

        # Criar repositório no ECR se não existir
        aws ecr describe-repositories --repository-names $IMAGE_NAME --region $AWS_REGION 2>/dev/null || \
            aws ecr create-repository --repository-name $IMAGE_NAME --region $AWS_REGION

        if [ "$USE_SKOPEO" = true ]; then
            # Usar skopeo (mais rápido, não precisa pull local)
            skopeo copy --src-tls-verify=false --dest-tls-verify=false \
                docker://$IMAGE \
                docker://$TARGET_IMAGE
        else
            # Usar docker
            docker pull $IMAGE
            docker tag $IMAGE $TARGET_IMAGE
            docker push $TARGET_IMAGE
            docker rmi $IMAGE $TARGET_IMAGE  # Limpar
        fi

        log_info "✓ Migrado: $IMAGE_NAME:$IMAGE_TAG"
    done

# Opção 2: Migrar para IBM ICR (conta Itaú)
elif [ "$TARGET_REGISTRY" != "" ] && [[ "$TARGET_REGISTRY" == *"icr.io"* ]]; then
    log_info "Target: IBM Container Registry (conta Itaú)"

    # Login no ICR de destino
    ibmcloud cr login

    for IMAGE in "${IMAGES[@]}"; do
        # Extrair nome e tag
        IMAGE_NAME=$(echo $IMAGE | cut -d'/' -f3 | cut -d':' -f1)
        IMAGE_TAG=$(echo $IMAGE | cut -d':' -f2)

        # Assumindo namespace "itau-namespace" no ICR - ajustar conforme necessário
        TARGET_NAMESPACE=$(echo $TARGET_REGISTRY | cut -d'/' -f2)
        TARGET_IMAGE="icr.io/${TARGET_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

        log_info "Migrando: $IMAGE → $TARGET_IMAGE"

        # Verificar se namespace existe, criar se não
        ibmcloud cr namespace-list | grep -q "$TARGET_NAMESPACE" || \
            ibmcloud cr namespace-add $TARGET_NAMESPACE

        if [ "$USE_SKOPEO" = true ]; then
            skopeo copy --src-tls-verify=false --dest-tls-verify=false \
                docker://$IMAGE \
                docker://$TARGET_IMAGE
        else
            docker pull $IMAGE
            docker tag $IMAGE $TARGET_IMAGE
            docker push $TARGET_IMAGE
            docker rmi $IMAGE $TARGET_IMAGE
        fi

        log_info "✓ Migrado: $IMAGE_NAME:$IMAGE_TAG"
    done
else
    log_error "TARGET_REGISTRY não configurado ou inválido"
    log_info "Configure TARGET_REGISTRY em config/migration.env"
    log_info "Exemplos:"
    log_info "  - AWS ECR: 123456789012.dkr.ecr.us-east-1.amazonaws.com"
    log_info "  - IBM ICR: icr.io/seu-namespace"
    exit 1
fi

echo ""
log_info "============================================"
log_info "Migração de Imagens Concluída!"
log_info "============================================"
echo ""

log_info "Próximos passos:"
log_info "1. Atualizar kustomize/airflow-test/kustomization.yaml com novos registries"
log_info "2. Atualizar kustomize/milvus/kustomization.yaml se necessário"
log_info "3. Testar pull das novas imagens:"
echo ""
echo "  docker pull $TARGET_IMAGE"
echo ""

# Criar arquivo com mapeamento de imagens
cat > ../config/image-mapping.txt <<EOF
# Mapeamento de Imagens Migradas
# Gerado em: $(date)

Original → Target
EOF

for IMAGE in "${IMAGES[@]}"; do
    IMAGE_NAME=$(echo $IMAGE | cut -d'/' -f3 | cut -d':' -f1)
    IMAGE_TAG=$(echo $IMAGE | cut -d':' -f2)
    echo "$IMAGE → ${TARGET_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" >> ../config/image-mapping.txt
done

log_info "Mapeamento salvo em: config/image-mapping.txt"
