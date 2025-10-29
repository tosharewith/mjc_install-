#!/bin/bash
#
# Script para gerar secrets automaticamente
# Gera Fernet Keys, JWT secrets, etc.
#

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Carregar configuração
if [ -f "config/migration.env" ]; then
    source config/migration.env
fi

# Carregar outputs do Terraform se existir
if [ -f "config/terraform-outputs.json" ]; then
    RDS_ENDPOINT=$(jq -r '.rds_endpoint.value' config/terraform-outputs.json)
    REDIS_ENDPOINT=$(jq -r '.redis_endpoint.value' config/terraform-outputs.json)
    S3_LOGS_BUCKET=$(jq -r '.s3_buckets.value.logs' config/terraform-outputs.json)
    S3_DAGS_BUCKET=$(jq -r '.s3_buckets.value.dags' config/terraform-outputs.json)
fi

# Criar diretório de secrets
mkdir -p config/secrets

log_info "Gerando secrets do Airflow..."

# Gerar Fernet Key se não existir
if [ ! -f "config/secrets/fernet-key" ]; then
    log_info "Gerando Fernet Key..."
    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" > config/secrets/fernet-key
else
    log_warn "Fernet Key já existe, pulando..."
fi

# Gerar JWT Secret
if [ ! -f "config/secrets/jwt-secret" ]; then
    log_info "Gerando JWT Secret..."
    openssl rand -hex 32 > config/secrets/jwt-secret
else
    log_warn "JWT Secret já existe, pulando..."
fi

# Gerar Webserver Secret Key
if [ ! -f "config/secrets/webserver-secret-key" ]; then
    log_info "Gerando Webserver Secret Key..."
    openssl rand -hex 32 > config/secrets/webserver-secret-key
else
    log_warn "Webserver Secret Key já existe, pulando..."
fi

# Criar arquivo de conexão PostgreSQL
log_info "Criando connection string do PostgreSQL..."
if [ -n "$RDS_ENDPOINT" ] && [ -n "$DB_USERNAME" ] && [ -n "$DB_PASSWORD" ]; then
    echo "postgresql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/airflow" > config/secrets/postgres-connection
else
    log_warn "RDS_ENDPOINT, DB_USERNAME ou DB_PASSWORD não definidos"
    echo "postgresql://USUARIO:SENHA@HOST:5432/airflow" > config/secrets/postgres-connection
fi

# Criar arquivo de conexão Redis
log_info "Criando connection string do Redis..."
if [ -n "$REDIS_ENDPOINT" ]; then
    echo "redis://${REDIS_ENDPOINT}:6379/0" > config/secrets/redis-connection
else
    log_warn "REDIS_ENDPOINT não definido"
    echo "redis://HOST:6379/0" > config/secrets/redis-connection
fi

# Criar certificado raiz do PostgreSQL (se necessário)
if [ ! -f "config/secrets/postgres-root-cert.crt" ]; then
    log_info "Baixando certificado raiz do RDS..."
    curl -so config/secrets/postgres-root-cert.crt https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
fi

# Criar secrets Kubernetes
log_info "Criando manifests de secrets Kubernetes..."

cat > kustomize/airflow-test/secrets/generated-secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: airflow-test-fernet-key
  namespace: airflow-test
type: Opaque
stringData:
  fernet-key: $(cat config/secrets/fernet-key)
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-test-jwt-secret
  namespace: airflow-test
type: Opaque
stringData:
  jwt-secret: $(cat config/secrets/jwt-secret)
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-test-webserver-secret-key
  namespace: airflow-test
type: Opaque
stringData:
  webserver-secret-key: $(cat config/secrets/webserver-secret-key)
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-postgres-connection-test
  namespace: airflow-test
type: Opaque
stringData:
  connection: $(cat config/secrets/postgres-connection)
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-redis-connection-test
  namespace: airflow-test
type: Opaque
stringData:
  connection: $(cat config/secrets/redis-connection)
---
apiVersion: v1
kind: Secret
metadata:
  name: airflow-postgres-cert-test
  namespace: airflow-test
type: Opaque
data:
  root.crt: $(base64 < config/secrets/postgres-root-cert.crt)
EOF

# Criar secrets para S3 (se usando IRSA - IAM Roles for Service Accounts)
if [ -n "$S3_LOGS_BUCKET" ]; then
    log_info "Configurando acesso S3..."

    cat > kustomize/airflow-test/patches/s3-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-s3-config
  namespace: airflow-test
data:
  AIRFLOW__LOGGING__REMOTE_LOGGING: "True"
  AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER: "s3://${S3_LOGS_BUCKET}/logs"
  AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID: "aws_default"
  AIRFLOW__CORE__DAGS_FOLDER: "s3://${S3_DAGS_BUCKET}/dags"
EOF
fi

# Criar ServiceAccount com annotation IRSA (opcional mas recomendado)
if [ -n "$IRSA_ROLE_ARN" ]; then
    log_info "Criando ServiceAccount com IRSA..."

    cat > kustomize/airflow-test/service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: airflow
  namespace: airflow-test
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF
fi

log_info "✓ Secrets gerados com sucesso!"
log_info ""
log_info "Arquivos criados:"
log_info "  - config/secrets/fernet-key"
log_info "  - config/secrets/jwt-secret"
log_info "  - config/secrets/webserver-secret-key"
log_info "  - config/secrets/postgres-connection"
log_info "  - config/secrets/redis-connection"
log_info "  - kustomize/airflow-test/secrets/generated-secrets.yaml"
log_info ""
log_warn "⚠️  NÃO COMMITE O DIRETÓRIO config/secrets/ NO GIT!"
log_info ""
