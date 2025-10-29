#!/bin/bash
#
# Script para configurar OAuth2 Proxy
# Substitui autenticação IBMid/w3id por OAuth2 genérico
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

if [ -f "config/migration.env" ]; then
    source config/migration.env
fi

log_info "Configurando OAuth2 Proxy..."

# Instalar OAuth2 Proxy via Helm
log_info "Instalando OAuth2 Proxy via Helm..."

helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update

# Criar valores para o Helm chart
cat > /tmp/oauth2-proxy-values.yaml <<EOF
config:
  clientID: "${OAUTH_CLIENT_ID}"
  clientSecret: "${OAUTH_CLIENT_SECRET}"
  cookieSecret: "$(openssl rand -base64 32 | head -c 32)"

extraArgs:
  provider: oidc
  oidc-issuer-url: "${OAUTH_ISSUER_URL}"
  email-domain: "*"
  cookie-secure: "true"
  cookie-expire: "24h"
  cookie-refresh: "1h"
  set-xauthrequest: "true"
  pass-access-token: "true"
  skip-provider-button: "false"

ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "${ACM_CERTIFICATE_ARN}"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
  hosts:
    - oauth.${BASE_DOMAIN}

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
EOF

helm upgrade --install oauth2-proxy oauth2-proxy/oauth2-proxy \
  --namespace oauth2-proxy \
  --create-namespace \
  --values /tmp/oauth2-proxy-values.yaml \
  --wait

log_info "OAuth2 Proxy instalado!"

# Criar Ingress annotations para Airflow usar OAuth
log_info "Configurando Ingress do Airflow para usar OAuth2 Proxy..."

cat > kustomize/airflow-test/patches/oauth-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: airflow-test
  namespace: airflow-test
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_CERTIFICATE_ARN}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    # OAuth2 Proxy annotations
    nginx.ingress.kubernetes.io/auth-url: "https://oauth.${BASE_DOMAIN}/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth.${BASE_DOMAIN}/oauth2/start?rd=\$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User, X-Auth-Request-Email"
spec:
  rules:
    - host: ${AIRFLOW_SUBDOMAIN}.${BASE_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: airflow-test-api-server
                port:
                  number: 8080
  tls:
    - hosts:
        - ${AIRFLOW_SUBDOMAIN}.${BASE_DOMAIN}
      secretName: airflow-tls
EOF

log_info "✓ OAuth2 Proxy configurado!"
log_info ""
log_info "URLs de acesso:"
log_info "  - OAuth2 Proxy: https://oauth.${BASE_DOMAIN}"
log_info "  - Airflow UI: https://${AIRFLOW_SUBDOMAIN}.${BASE_DOMAIN}"
log_info ""
log_info "Próximos passos:"
log_info "  1. Configure seu provedor OAuth (Azure AD, Okta, Google, etc.)"
log_info "  2. Adicione as URLs de callback no provedor:"
log_info "     - https://oauth.${BASE_DOMAIN}/oauth2/callback"
log_info "  3. Atualize config/migration.env com CLIENT_ID e CLIENT_SECRET"
log_info "  4. Teste o acesso via browser"
