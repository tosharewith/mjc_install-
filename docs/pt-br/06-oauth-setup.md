# Configuração de Autenticação OAuth2

Este documento detalha a configuração de autenticação OAuth2 Proxy para substituir IBMid/w3id.

## Visão Geral

No IBM IKS, a autenticação era feita via IBMid/w3id integrado ao IBM Cloud.
No AWS EKS, usaremos OAuth2 Proxy com OIDC (OpenID Connect) para autenticação.

## Provedores Suportados

O OAuth2 Proxy suporta diversos provedores:
- **Azure AD / Entra ID** (recomendado para ambientes corporativos)
- **Okta**
- **Google Workspace**
- **Keycloak**
- **Generic OIDC**

Este guia usará **Azure AD** como exemplo.

## Arquitetura

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │ 1. Acessa https://airflow.exemplo.com
       ↓
┌─────────────────────────────────────────┐
│         AWS ALB (Ingress)               │
└──────┬──────────────────────────────────┘
       │ 2. Redireciona para OAuth2 Proxy
       ↓
┌─────────────────────────────────────────┐
│        OAuth2 Proxy (Pod)               │
│  - Verifica se autenticado              │
│  - Se não, redireciona para Azure AD    │
└──────┬──────────────────────────────────┘
       │ 3. Redireciona para Azure AD
       ↓
┌─────────────────────────────────────────┐
│           Azure AD                      │
│  - Usuário faz login                    │
│  - Retorna token                        │
└──────┬──────────────────────────────────┘
       │ 4. Callback com token
       ↓
┌─────────────────────────────────────────┐
│        OAuth2 Proxy                     │
│  - Valida token                         │
│  - Cria sessão                          │
│  - Proxy request para backend           │
└──────┬──────────────────────────────────┘
       │ 5. Request autenticado
       ↓
┌─────────────────────────────────────────┐
│     Airflow API Server                  │
└─────────────────────────────────────────┘
```

## Pré-requisitos

- [ ] Aplicação registrada no Azure AD (ou outro provedor)
- [ ] Client ID e Client Secret
- [ ] Tenant ID (Azure AD)
- [ ] Domínio configurado (ex: airflow.exemplo.com)
- [ ] Certificado SSL no ACM

## Passo a Passo

### Etapa 1: Registrar Aplicação no Azure AD

#### 1.1. Criar App Registration

1. Acessar Azure Portal → Azure Active Directory → App registrations
2. Clicar em "New registration"
3. Preencher:
   - Name: `Airflow EKS Production`
   - Redirect URI: `https://airflow.exemplo.com/oauth2/callback`
4. Clicar em "Register"

#### 1.2. Obter Credenciais

```bash
# Client ID
CLIENT_ID="12345678-1234-1234-1234-123456789abc"

# Tenant ID
TENANT_ID="87654321-4321-4321-4321-cba987654321"

# Criar Client Secret
# Azure Portal → App registration → Certificates & secrets → New client secret
CLIENT_SECRET="seu-client-secret-aqui"
```

#### 1.3. Configurar Permissões

- Azure Portal → App registration → API permissions
- Adicionar permissão: `Microsoft Graph` → `User.Read`
- Grant admin consent

### Etapa 2: Deploy OAuth2 Proxy

#### 2.1. Criar Secret

```bash
# Gerar cookie secret
COOKIE_SECRET=$(openssl rand -base64 32)

# Criar secret no Kubernetes
kubectl create secret generic oauth2-proxy-secrets \
  --from-literal=client-id="$CLIENT_ID" \
  --from-literal=client-secret="$CLIENT_SECRET" \
  --from-literal=cookie-secret="$COOKIE_SECRET" \
  -n airflow-test
```

#### 2.2. Criar ConfigMap

```yaml
# oauth2-proxy-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
  namespace: airflow-test
data:
  oauth2_proxy.cfg: |
    # Provider
    provider = "azure"
    azure_tenant = "87654321-4321-4321-4321-cba987654321"

    # Email domains permitidos
    email_domains = [
      "exemplo.com",
      "itau.com.br"
    ]

    # Ou permitir qualquer email autenticado
    # email_domains = ["*"]

    # Upstream (backend)
    http_address = "0.0.0.0:4180"
    upstreams = [
      "http://airflow-test-api-server:8080"
    ]

    # Cookie
    cookie_secure = true
    cookie_httponly = true
    cookie_name = "_oauth2_proxy"
    cookie_expire = "168h"  # 7 dias

    # Session
    session_store_type = "cookie"

    # Paths
    skip_auth_regex = [
      "^/health$",
      "^/api/v1/health$"
    ]
```

```bash
kubectl apply -f oauth2-proxy-configmap.yaml
```

#### 2.3. Deploy OAuth2 Proxy

```yaml
# oauth2-proxy-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: airflow-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
        args:
        - --config=/etc/oauth2_proxy/oauth2_proxy.cfg
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secrets
              key: client-id
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secrets
              key: client-secret
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secrets
              key: cookie-secret
        ports:
        - containerPort: 4180
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/oauth2_proxy
        livenessProbe:
          httpGet:
            path: /ping
            port: 4180
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /ping
            port: 4180
          initialDelaySeconds: 5
      volumes:
      - name: config
        configMap:
          name: oauth2-proxy-config
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: airflow-test
spec:
  selector:
    app: oauth2-proxy
  ports:
  - port: 4180
    targetPort: 4180
    name: http
```

```bash
kubectl apply -f oauth2-proxy-deployment.yaml
```

### Etapa 3: Configurar Ingress

#### 3.1. Atualizar Ingress do Airflow

```yaml
# airflow-ingress-with-auth.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: airflow-ingress
  namespace: airflow-test
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789:certificate/xxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
  - host: airflow.exemplo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy
            port:
              number: 4180
```

```bash
kubectl apply -f airflow-ingress-with-auth.yaml
```

### Etapa 4: Validar Autenticação

#### 4.1. Obter ALB URL

```bash
kubectl get ingress -n airflow-test

# Output:
# NAME              CLASS   HOSTS                 ADDRESS                           PORTS
# airflow-ingress   alb     airflow.exemplo.com   xxx.us-east-1.elb.amazonaws.com   80
```

#### 4.2. Atualizar DNS

```bash
# Criar registro CNAME
# airflow.exemplo.com → xxx.us-east-1.elb.amazonaws.com

# Ou via Route 53 CLI
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "airflow.exemplo.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "xxx.us-east-1.elb.amazonaws.com"}]
      }
    }]
  }'
```

#### 4.3. Testar Login

```bash
# Abrir no browser
open https://airflow.exemplo.com

# Deve redirecionar para Azure AD login
# Após login, deve retornar para Airflow UI
```

## Configurações Avançadas

### Grupos do Azure AD

Para restringir acesso por grupo:

```yaml
# oauth2-proxy-configmap.yaml (adicionar)
data:
  oauth2_proxy.cfg: |
    # ...
    azure_groups = [
      "Airflow-Users",
      "Airflow-Admins"
    ]
```

### Whitelist de Usuários

```yaml
data:
  oauth2_proxy.cfg: |
    # ...
    authenticated_emails_file = "/etc/oauth2_proxy/emails.txt"
```

```bash
# Criar ConfigMap com lista de emails
kubectl create configmap oauth2-proxy-emails \
  --from-literal=emails.txt="user1@exemplo.com
user2@exemplo.com
user3@exemplo.com" \
  -n airflow-test
```

### Redis para Session Store

Para ambientes com múltiplas réplicas:

```yaml
data:
  oauth2_proxy.cfg: |
    # ...
    session_store_type = "redis"
    redis_connection_url = "redis://redis-endpoint:6379"
```

## Troubleshooting

### Redirect Loop

```bash
# Verificar logs
kubectl logs -n airflow-test -l app=oauth2-proxy

# Verificar redirect URI no Azure AD
# Deve ser: https://airflow.exemplo.com/oauth2/callback
```

### Erro "Invalid Client"

```bash
# Verificar Client ID e Secret
kubectl get secret oauth2-proxy-secrets -n airflow-test -o yaml

# Verificar no Azure AD Portal
# App registrations → Certificates & secrets
```

### Cookie não persiste

```bash
# Verificar domain no ConfigMap
data:
  oauth2_proxy.cfg: |
    cookie_domains = [".exemplo.com"]
    whitelist_domains = [".exemplo.com"]
```

## Checklist de Validação

- [ ] App registration criado no Azure AD
- [ ] Redirect URI configurado corretamente
- [ ] Client ID e Secret configurados no secret
- [ ] OAuth2 Proxy pods estão Running
- [ ] Ingress aponta para OAuth2 Proxy
- [ ] DNS configurado
- [ ] Certificado SSL válido
- [ ] Login funciona via Azure AD
- [ ] Redirecionamento para Airflow funciona
- [ ] Logout funciona

## Próximos Passos

Após configurar autenticação, prossiga para [07-validacao.md](07-validacao.md).
