# Pré-requisitos para Migração

Este documento lista todos os pré-requisitos necessários antes de iniciar a migração do IBM IKS para AWS EKS.

## Ferramentas Necessárias

### 1. Cliente AWS (AWS CLI)

```bash
# Verificar instalação
aws --version

# Versão mínima: AWS CLI v2
# Se não instalado:
# macOS: brew install awscli
# Linux: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
```

### 2. Terraform

```bash
# Verificar instalação
terraform --version

# Versão mínima: 1.5.0
# Se não instalado:
# macOS: brew install terraform
# Linux: https://www.terraform.io/downloads
```

### 3. kubectl

```bash
# Verificar instalação
kubectl version --client

# Versão mínima: 1.27
# Se não instalado:
# macOS: brew install kubectl
# Linux: https://kubernetes.io/docs/tasks/tools/
```

### 4. Helm

```bash
# Verificar instalação
helm version

# Versão mínima: 3.12
# Se não instalado:
# macOS: brew install helm
# Linux: https://helm.sh/docs/intro/install/
```

### 5. Kustomize

```bash
# Verificar instalação
kustomize version

# Versão mínima: 5.0
# Se não instalado:
# macOS: brew install kustomize
# Linux: https://kubectl.docs.kubernetes.io/installation/kustomize/
```

### 6. Docker (opcional)

```bash
# Para migração de imagens
docker --version

# Versão mínima: 20.10
```

## Acessos Necessários

### AWS

- Credenciais AWS configuradas com permissões para:
  - Amazon EKS (criar e gerenciar clusters)
  - Amazon RDS (criar instâncias PostgreSQL)
  - Redis as Cache (criar clusters Redis)
  - Amazon S3 (criar e gerenciar buckets)
  - Amazon IAM (criar roles e policies)
  - Amazon VPC (gerenciar networking)
  - Amazon EBS (gerenciar volumes)

### Kubernetes

- Acesso ao cluster IBM IKS (mjc-cluster) com permissões de leitura
- Acesso ao cluster AWS EKS com permissões de administrador

### Container Registry

- Acesso ao IBM Container Registry (icr.io) para pull de imagens
- Acesso ao AWS ECR (ou outro registry) para push de imagens

## Configuração Inicial

### 1. Configurar AWS CLI

```bash
# Configurar credenciais
aws configure

# Ou usar perfil específico
export AWS_PROFILE=seu-perfil

# Validar acesso
aws sts get-caller-identity
```

### 2. Configurar kubectl para EKS

```bash
# Atualizar kubeconfig
aws eks update-kubeconfig --name SEU_CLUSTER_EKS --region us-east-1

# Validar acesso
kubectl cluster-info
kubectl get nodes
```

### 3. Clonar este repositório

```bash
git clone <repo-url>
cd mjc_install-
```

### 4. Copiar configuração de exemplo

```bash
# Copiar arquivo de configuração
cp config/migration.env.example config/migration.env

# Editar com suas configurações
vim config/migration.env
```

## Informações a Coletar

Antes de iniciar a migração, colete as seguintes informações:

### Do Ambiente IBM IKS

- [ ] Endpoints de serviços atuais
- [ ] Strings de conexão de banco de dados
- [ ] Valores atuais de secrets
- [ ] Configurações de recursos (CPU, memória)
- [ ] Configurações de storage (tamanhos de PVCs)
- [ ] Variáveis de ambiente dos pods
- [ ] Configurações de ingress/routes

### Do Ambiente AWS EKS

- [ ] Nome do cluster EKS
- [ ] Região AWS
- [ ] VPC ID
- [ ] Subnet IDs (privadas e públicas)
- [ ] Security Groups
- [ ] Domínio para aplicações
- [ ] Certificado SSL (ARN no ACM)
- [ ] Account ID AWS

## Validação dos Pré-requisitos

Execute o script de validação:

```bash
./scripts/validate-prerequisites.sh
```

Este script verificará:
- Versões de ferramentas instaladas
- Acesso ao AWS
- Acesso ao cluster EKS
- Permissões necessárias

## Próximos Passos

Após validar todos os pré-requisitos, prossiga para [02-planejamento.md](02-planejamento.md).
