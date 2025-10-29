#!/bin/bash
#
# Script de Validação da Migração
# Valida que todos os componentes estão funcionando corretamente
#

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

FAILED_TESTS=0

test_passed() {
    log_info "$1"
}

test_failed() {
    log_error "$1"
    ((FAILED_TESTS++))
}

echo "╔═══════════════════════════════════════════════════════╗"
echo "║     Validação da Migração                             ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# ============================================
# 1. Validar Namespaces
# ============================================
echo "1️⃣  Validando Namespaces..."

if kubectl get namespace airflow-test &>/dev/null; then
    test_passed "Namespace airflow-test existe"
else
    test_failed "Namespace airflow-test não encontrado"
fi

if kubectl get namespace milvus-dev &>/dev/null; then
    test_passed "Namespace milvus-dev existe"
else
    test_failed "Namespace milvus-dev não encontrado"
fi

# ============================================
# 2. Validar Pods do Airflow
# ============================================
echo ""
echo "2️⃣  Validando Pods do Airflow..."

AIRFLOW_PODS=(
    "api-server"
    "scheduler"
    "dag-processor"
    "worker"
    "triggerer"
)

for component in "${AIRFLOW_PODS[@]}"; do
    READY=$(kubectl get pods -n airflow-test -l component=$component -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$READY" = "True" ]; then
        test_passed "Airflow $component está rodando"
    else
        test_failed "Airflow $component não está pronto"
    fi
done

# ============================================
# 3. Validar Pods do Milvus
# ============================================
echo ""
echo "3️⃣  Validando Pods do Milvus..."

MILVUS_COMPONENTS=(
    "etcd"
    "minio"
    "kafka"
    "zookeeper"
    "datanode"
    "indexnode"
    "querynode"
    "mixcoord"
    "proxy"
)

for component in "${MILVUS_COMPONENTS[@]}"; do
    POD_COUNT=$(kubectl get pods -n milvus-dev -l app.kubernetes.io/component=$component 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$POD_COUNT" -gt 0 ]; then
        test_passed "Milvus $component tem $POD_COUNT pod(s) rodando"
    else
        test_failed "Milvus $component não tem pods rodando"
    fi
done

# ============================================
# 4. Validar Services
# ============================================
echo ""
echo "4️⃣  Validando Services..."

# Airflow
if kubectl get svc -n airflow-test airflow-test-api-server &>/dev/null; then
    test_passed "Service airflow-test-api-server existe"
else
    test_failed "Service airflow-test-api-server não encontrado"
fi

# Milvus
if kubectl get svc -n milvus-dev milvus-mmjc-dev &>/dev/null; then
    test_passed "Service milvus-mmjc-dev existe"
else
    test_failed "Service milvus-mmjc-dev não encontrado"
fi

# ============================================
# 5. Validar Conectividade com RDS
# ============================================
echo ""
echo "5️⃣  Validando Conectividade com RDS..."

if [ -f "config/terraform-outputs.json" ]; then
    RDS_ENDPOINT=$(jq -r '.rds_endpoint.value' config/terraform-outputs.json)

    # Testar conexão do pod do Airflow
    AIRFLOW_POD=$(kubectl get pods -n airflow-test -l component=scheduler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$AIRFLOW_POD" ]; then
        if kubectl exec -n airflow-test $AIRFLOW_POD -- sh -c "airflow db check" &>/dev/null; then
            test_passed "Airflow consegue conectar ao banco de dados"
        else
            test_failed "Airflow não consegue conectar ao banco de dados"
        fi
    fi
else
    test_warn "Outputs do Terraform não encontrados, pulando teste de RDS"
fi

# ============================================
# 6. Validar Conectividade com Redis
# ============================================
echo ""
echo "6️⃣  Validando Conectividade com Redis..."

if [ -n "$AIRFLOW_POD" ]; then
    if kubectl exec -n airflow-test $AIRFLOW_POD -- sh -c "python -c 'from airflow.configuration import conf; from redis import Redis; r = Redis.from_url(conf.get(\"celery\", \"broker_url\")); r.ping()'" &>/dev/null; then
        test_passed "Airflow consegue conectar ao Redis"
    else
        test_failed "Airflow não consegue conectar ao Redis"
    fi
fi

# ============================================
# 7. Validar PVCs
# ============================================
echo ""
echo "7️⃣  Validando Persistent Volume Claims..."

# Airflow Worker
if kubectl get pvc -n airflow-test data-airflow-test-worker-0 &>/dev/null; then
    STATUS=$(kubectl get pvc -n airflow-test data-airflow-test-worker-0 -o jsonpath='{.status.phase}')
    if [ "$STATUS" = "Bound" ]; then
        test_passed "PVC do Worker está Bound"
    else
        test_failed "PVC do Worker está $STATUS"
    fi
fi

# ============================================
# 8. Validar Ingress/ALB
# ============================================
echo ""
echo "8️⃣  Validando Ingress..."

if kubectl get ingress -n airflow-test &>/dev/null; then
    ALB_ENDPOINT=$(kubectl get ingress -n airflow-test -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ALB_ENDPOINT" ]; then
        test_passed "ALB configurado: $ALB_ENDPOINT"
    else
        test_warn "ALB ainda não provisionado (pode levar alguns minutos)"
    fi
else
    test_warn "Nenhum Ingress configurado"
fi

# ============================================
# 9. Validar Logs
# ============================================
echo ""
echo "9️⃣  Validando Logs dos Pods..."

# Verificar se há erros críticos nos logs recentes
AIRFLOW_SCHEDULER=$(kubectl get pods -n airflow-test -l component=scheduler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$AIRFLOW_SCHEDULER" ]; then
    ERROR_COUNT=$(kubectl logs -n airflow-test $AIRFLOW_SCHEDULER --tail=100 | grep -ci "error\|critical\|exception" || echo "0")
    if [ "$ERROR_COUNT" -lt 5 ]; then
        test_passed "Logs do Scheduler parecem normais (< 5 erros nos últimos 100 logs)"
    else
        test_warn "Scheduler tem $ERROR_COUNT erros/exceptions nos últimos logs"
    fi
fi

# ============================================
# 10. Validar ConfigMaps e Secrets
# ============================================
echo ""
echo "🔟 Validando ConfigMaps e Secrets..."

REQUIRED_SECRETS=(
    "airflow-test-fernet-key"
    "airflow-postgres-connection-test"
    "airflow-redis-connection-test"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
    if kubectl get secret -n airflow-test $secret &>/dev/null; then
        test_passed "Secret $secret existe"
    else
        test_failed "Secret $secret não encontrado"
    fi
done

# ============================================
# Resumo
# ============================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ VALIDAÇÃO COMPLETA - TODOS OS TESTES PASSARAM!${NC}"
    echo ""
    echo "Próximos passos recomendados:"
    echo "  1. Acesse o Airflow UI e valide as DAGs"
    echo "  2. Execute uma DAG de teste"
    echo "  3. Verifique os logs no S3"
    echo "  4. Teste o Milvus com uma query"
    echo "  5. Configure o monitoramento (CloudWatch, Prometheus, etc.)"
    exit 0
else
    echo -e "${RED}❌ VALIDAÇÃO FALHOU - $FAILED_TESTS TESTE(S) FALHARAM${NC}"
    echo ""
    echo "Ações recomendadas:"
    echo "  1. Revise os logs dos pods com erros:"
    echo "     kubectl logs -n <namespace> <pod-name>"
    echo "  2. Verifique os events:"
    echo "     kubectl get events -n <namespace> --sort-by='.lastTimestamp'"
    echo "  3. Valide as configurações nos secrets e configmaps"
    echo "  4. Consulte o guia de troubleshooting: docs/pt-br/08-troubleshooting.md"
    exit 1
fi
