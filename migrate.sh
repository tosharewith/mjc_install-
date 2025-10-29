#!/bin/bash
#
# Script Master de Migração IBM IKS → AWS EKS
# Automatiza todo o processo de migração
#
# Usage: ./migrate.sh [--dry-run] [--skip-terraform] [--skip-airflow] [--skip-milvus]
#

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função de log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log_info "Verificando pré-requisitos..."

    local missing=0

    # Verificar ferramentas
    for tool in terraform kubectl aws helm kustomize jq; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool não está instalado"
            missing=1
        else
            log_info "✓ $tool instalado"
        fi
    done

    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "Credenciais AWS não configuradas ou inválidas"
        missing=1
    else
        log_info "✓ Credenciais AWS válidas"
    fi

    # Verificar acesso ao cluster EKS
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Não foi possível acessar o cluster Kubernetes"
        missing=1
    else
        log_info "✓ Acesso ao cluster Kubernetes"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Pré-requisitos faltando. Execute: ./scripts/setup-prerequisites.sh"
        exit 1
    fi

    log_info "Todos os pré-requisitos atendidos!"
}

# Função para carregar configuração
load_config() {
    log_info "Carregando configuração..."

    if [ ! -f "config/migration.env" ]; then
        log_error "Arquivo de configuração não encontrado: config/migration.env"
        log_info "Copie config/migration.env.example para config/migration.env e edite"
        exit 1
    fi

    source config/migration.env

    log_info "✓ Configuração carregada"
    log_info "  - Cluster EKS: $EKS_CLUSTER_NAME"
    log_info "  - Região AWS: $AWS_REGION"
    log_info "  - Ambiente: $ENVIRONMENT"
}

# Função para criar infraestrutura com Terraform
setup_infrastructure() {
    if [ "$SKIP_TERRAFORM" = "true" ]; then
        log_warn "Pulando criação de infraestrutura (--skip-terraform)"
        return
    fi

    log_info "============================================"
    log_info "FASE 1: Criando Infraestrutura AWS"
    log_info "============================================"

    cd terraform/environments/$ENVIRONMENT

    # Backup do state se existir
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
        log_info "Backup do state criado"
    fi

    # Inicializar Terraform
    log_info "Inicializando Terraform..."
    terraform init -upgrade

    # Validar configuração
    log_info "Validando configuração Terraform..."
    terraform validate

    # Planejar mudanças
    log_info "Gerando plano de execução..."
    terraform plan -out=tfplan

    if [ "$DRY_RUN" = "true" ]; then
        log_warn "Modo dry-run ativado. Não aplicando mudanças."
        cd ../../..
        return
    fi

    # Aplicar mudanças
    log_info "Aplicando infraestrutura..."
    terraform apply -auto-approve tfplan

    # Salvar outputs
    log_info "Salvando outputs..."
    terraform output -json > ../../../config/terraform-outputs.json

    # Extrair informações importantes
    export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
    export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    export S3_LOGS_BUCKET=$(terraform output -raw s3_buckets | jq -r '.logs')
    export S3_DAGS_BUCKET=$(terraform output -raw s3_buckets | jq -r '.dags')
    export S3_MILVUS_BUCKET=$(terraform output -raw s3_buckets | jq -r '.milvus')

    log_info "✓ Infraestrutura criada com sucesso"
    log_info "  - RDS: $RDS_ENDPOINT"
    log_info "  - Redis: $REDIS_ENDPOINT"
    log_info "  - S3 Buckets: $S3_LOGS_BUCKET, $S3_DAGS_BUCKET, $S3_MILVUS_BUCKET"

    cd ../../..
}

# Função para gerar secrets
generate_secrets() {
    log_info "============================================"
    log_info "FASE 2: Gerando Secrets"
    log_info "============================================"

    ./scripts/generate-secrets.sh

    log_info "✓ Secrets gerados"
}

# Função para migrar Airflow
migrate_airflow() {
    if [ "$SKIP_AIRFLOW" = "true" ]; then
        log_warn "Pulando migração do Airflow (--skip-airflow)"
        return
    fi

    log_info "============================================"
    log_info "FASE 3: Migrando Airflow"
    log_info "============================================"

    # Criar namespace
    log_info "Criando namespace airflow-test..."
    kubectl create namespace airflow-test --dry-run=client -o yaml | kubectl apply -f -

    # Aplicar secrets
    log_info "Aplicando secrets..."
    kubectl apply -k kustomize/airflow-test/secrets/

    # Aplicar manifestos base
    log_info "Aplicando manifestos do Airflow..."
    if [ "$DRY_RUN" = "true" ]; then
        kubectl apply -k kustomize/airflow-test/ --dry-run=client
    else
        kubectl apply -k kustomize/airflow-test/
    fi

    # Aguardar pods ficarem prontos
    if [ "$DRY_RUN" != "true" ]; then
        log_info "Aguardando pods do Airflow ficarem prontos..."
        kubectl wait --for=condition=ready pod -l app=airflow -n airflow-test --timeout=600s
    fi

    log_info "✓ Airflow migrado com sucesso"
}

# Função para migrar Milvus
migrate_milvus() {
    if [ "$SKIP_MILVUS" = "true" ]; then
        log_warn "Pulando migração do Milvus (--skip-milvus)"
        return
    fi

    log_info "============================================"
    log_info "FASE 4: Migrando Milvus"
    log_info "============================================"

    # Criar namespace
    log_info "Criando namespace milvus-dev..."
    kubectl create namespace milvus-dev --dry-run=client -o yaml | kubectl apply -f -

    # Aplicar secrets
    log_info "Aplicando secrets..."
    kubectl apply -k kustomize/milvus/secrets/

    # Aplicar manifestos base
    log_info "Aplicando manifestos do Milvus..."
    if [ "$DRY_RUN" = "true" ]; then
        kubectl apply -k kustomize/milvus/ --dry-run=client
    else
        kubectl apply -k kustomize/milvus/
    fi

    # Aguardar StatefulSets ficarem prontos
    if [ "$DRY_RUN" != "true" ]; then
        log_info "Aguardando StatefulSets do Milvus ficarem prontos..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=milvus-mmjc-dev -n milvus-dev --timeout=900s || true
    fi

    log_info "✓ Milvus migrado com sucesso"
}

# Função para configurar OAuth
setup_oauth() {
    log_info "============================================"
    log_info "FASE 5: Configurando OAuth2 Proxy"
    log_info "============================================"

    ./scripts/setup-oauth-proxy.sh

    log_info "✓ OAuth2 Proxy configurado"
}

# Função para validar migração
validate_migration() {
    log_info "============================================"
    log_info "FASE 6: Validando Migração"
    log_info "============================================"

    ./scripts/validate-migration.sh
}

# Função principal
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║     Migração IBM IKS → AWS EKS                        ║"
    echo "║     Airflow Test + Milvus Dev                         ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    # Parse argumentos
    DRY_RUN=false
    SKIP_TERRAFORM=false
    SKIP_AIRFLOW=false
    SKIP_MILVUS=false

    for arg in "$@"; do
        case $arg in
            --dry-run)
                DRY_RUN=true
                log_warn "Modo DRY-RUN ativado - nenhuma mudança será aplicada"
                ;;
            --skip-terraform)
                SKIP_TERRAFORM=true
                ;;
            --skip-airflow)
                SKIP_AIRFLOW=true
                ;;
            --skip-milvus)
                SKIP_MILVUS=true
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run          Simula execução sem fazer mudanças"
                echo "  --skip-terraform   Pula criação de infraestrutura"
                echo "  --skip-airflow     Pula migração do Airflow"
                echo "  --skip-milvus      Pula migração do Milvus"
                echo "  --help             Mostra esta ajuda"
                exit 0
                ;;
        esac
    done

    # Executar fases
    check_prerequisites
    load_config

    if [ "$DRY_RUN" = "true" ]; then
        log_warn "═══════════════════════════════════════"
        log_warn "MODO DRY-RUN - SIMULAÇÃO"
        log_warn "═══════════════════════════════════════"
    fi

    setup_infrastructure
    generate_secrets
    migrate_airflow
    migrate_milvus
    setup_oauth
    validate_migration

    echo ""
    log_info "╔═══════════════════════════════════════════════════════╗"
    log_info "║     MIGRAÇÃO CONCLUÍDA COM SUCESSO! 🎉                ║"
    log_info "╚═══════════════════════════════════════════════════════╝"
    echo ""

    log_info "Próximos passos:"
    log_info "1. Verifique os logs dos pods: kubectl logs -n airflow-test <pod>"
    log_info "2. Acesse o Airflow UI: kubectl port-forward -n airflow-test svc/airflow-test-api-server 8080:8080"
    log_info "3. Valide as DAGs estão carregando corretamente"
    log_info "4. Teste conexões com RDS e Redis"
    log_info "5. Configure DNS para apontar para o novo ALB"
    echo ""
}

# Executar
main "$@"
