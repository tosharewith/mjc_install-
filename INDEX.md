# Índice Completo da Documentação - Migração IKS → EKS

## 📑 Documentação Principal

### Guias de Início Rápido
- **[README.md](README.md)** - Visão geral do projeto
- **[MIGRATION_QUICKSTART.md](MIGRATION_QUICKSTART.md)** - Guia rápido de migração (COMECE AQUI!)
- **[START_HERE.md](START_HERE.md)** - Ponto de partida alternativo

### Instalação via Helm (Recomendado!)
- **[AIRFLOW_HELM_INSTALL.md](AIRFLOW_HELM_INSTALL.md)** - Instalação do Airflow via Helm Chart oficial
- **[MILVUS_HELM_INSTALL.md](MILVUS_HELM_INSTALL.md)** - Instalação do Milvus via Helm Chart oficial

## 📚 Guias Detalhados (docs/pt-br/)

### Fase 1: Preparação
- **[01-pre-requisitos.md](docs/pt-br/01-pre-requisitos.md)**
  - Ferramentas necessárias (Terraform, kubectl, Helm, AWS CLI)
  - Acessos AWS e Kubernetes
  - Configuração inicial
  - Validação de pré-requisitos

### Fase 2: Planejamento
- **[02-planejamento.md](docs/pt-br/02-planejamento.md)**
  - Diferenças entre IKS e EKS
  - Arquitetura alvo
  - Estratégia de migração
  - Riscos e mitigações
  - Timeline

### Fase 3: Infraestrutura
- **[03-terraform-setup.md](docs/pt-br/03-terraform-setup.md)**
  - Setup do backend do Terraform
  - Criação de RDS PostgreSQL
  - Criação de Redis as Cache
  - Criação de S3 Buckets
  - Validação de recursos

### Fase 4: Migração Airflow
- **[04-airflow-migration.md](docs/pt-br/04-airflow-migration.md)**
  - Preparação de configurações
  - Criação de secrets
  - Sincronização de DAGs
  - Deploy no EKS
  - Validação

### Fase 5: Migração Milvus
- **[05-milvus-migration.md](docs/pt-br/05-milvus-migration.md)**
  - Deploy da infraestrutura (Etcd, Kafka, Zookeeper, MinIO)
  - Deploy dos componentes Milvus
  - Migração de dados
  - Validação

### Fase 6: Autenticação
- **[06-oauth-setup.md](docs/pt-br/06-oauth-setup.md)**
  - Configuração do OAuth2 Proxy
  - Integração com Azure AD
  - Configuração de ingress
  - Testes de autenticação

### Fase 7: Validação
- **[07-validacao.md](docs/pt-br/07-validacao.md)**
  - Checklist de validação
  - Testes de conectividade
  - Validação de componentes
  - Scripts de validação automatizada
  - Monitoramento

### Fase 8: Troubleshooting
- **[08-troubleshooting.md](docs/pt-br/08-troubleshooting.md)**
  - Problemas comuns e soluções
  - Airflow (scheduler, workers, DAGs, logs)
  - Milvus (Etcd, Kafka, API)
  - Storage (PVCs)
  - Rede (ingress, DNS)
  - RDS/Redis
  - OAuth2

## ⚙️ Configurações Helm

### Airflow
- **[helm/airflow-values-aws-eks.yaml](helm/airflow-values-aws-eks.yaml)**
  - Configuração completa do Airflow para EKS
  - Baseado na configuração atual do `airflow-test` no IKS
  - Adaptações para AWS (storage, node selectors, etc)
  - Recursos, réplicas, e configurações

### Milvus
- **[helm/milvus-values-aws-eks.yaml](helm/milvus-values-aws-eks.yaml)**
  - Configuração completa do Milvus para EKS
  - Baseado na configuração atual do `milvus-mmjc-test` no IKS
  - Adaptações para AWS (storage class gp3)
  - Componentes, réplicas e recursos

## 🗂️ Outros Documentos

### Documentação Técnica
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Informações de deployment
- **[INSTALLATION_SUMMARY.md](INSTALLATION_SUMMARY.md)** - Resumo da instalação
- **[MIGRATION_OVERVIEW.md](MIGRATION_OVERVIEW.md)** - Visão geral da migração
- **[MIGRATION_WORKFLOW.md](MIGRATION_WORKFLOW.md)** - Workflow de migração

### Guias Específicos
- **[DOCKER_PULL_COMMANDS.md](DOCKER_PULL_COMMANDS.md)** - Comandos para pull de imagens
- **[IMAGE_MIGRATION_ANALYSIS.md](IMAGE_MIGRATION_ANALYSIS.md)** - Análise de imagens
- **[JFROG_ARTIFACTORY_SETUP.md](JFROG_ARTIFACTORY_SETUP.md)** - Setup JFrog
- **[AWS_SERVICES_REQUIRED.md](AWS_SERVICES_REQUIRED.md)** - Serviços AWS necessários
- **[SERVICES_AND_IMAGES_GUIDE.md](SERVICES_AND_IMAGES_GUIDE.md)** - Guia de serviços e imagens

### Status e Sumários
- **[MIGRATION_STATUS.md](MIGRATION_STATUS.md)** - Status da migração
- **[MIGRATION_STATUS_FINAL.md](MIGRATION_STATUS_FINAL.md)** - Status final
- **[MIGRATION_COMPLETE_SUCCESS.md](MIGRATION_COMPLETE_SUCCESS.md)** - Sucesso completo
- **[FINAL_MIGRATION_STATUS.md](FINAL_MIGRATION_STATUS.md)** - Status final detalhado
- **[SUCCESS_PARTIAL_MIGRATION.md](SUCCESS_PARTIAL_MIGRATION.md)** - Sucesso parcial
- **[SUMMARY.md](SUMMARY.md)** - Sumário geral

### Guides Rápidos
- **[QUICKSTART.md](QUICKSTART.md)** - Início rápido (versão 1)
- **[QUICKSTART_MANUAL_MIGRATION.md](QUICKSTART_MANUAL_MIGRATION.md)** - Migração manual
- **[RUN_MIGRATION_NOW.md](RUN_MIGRATION_NOW.md)** - Executar migração agora

### Soluções
- **[QUOTA_SOLUTIONS.md](QUOTA_SOLUTIONS.md)** - Soluções para problemas de quota
- **[CORRECTED_MIGRATION_READY.md](CORRECTED_MIGRATION_READY.md)** - Migração corrigida

## 🎯 Fluxo Recomendado de Leitura

### Para Iniciantes (Nunca fez migração antes)
1. [README.md](README.md) - Entender o projeto
2. [MIGRATION_QUICKSTART.md](MIGRATION_QUICKSTART.md) - Visão rápida
3. [docs/pt-br/01-pre-requisitos.md](docs/pt-br/01-pre-requisitos.md) - Preparar ambiente
4. [docs/pt-br/02-planejamento.md](docs/pt-br/02-planejamento.md) - Planejar
5. [AIRFLOW_HELM_INSTALL.md](AIRFLOW_HELM_INSTALL.md) - Instalar Airflow
6. [MILVUS_HELM_INSTALL.md](MILVUS_HELM_INSTALL.md) - Instalar Milvus

### Para Quem Quer Fazer Rápido (Já sabe o que está fazendo)
1. [MIGRATION_QUICKSTART.md](MIGRATION_QUICKSTART.md) - Comandos essenciais
2. [helm/airflow-values-aws-eks.yaml](helm/airflow-values-aws-eks.yaml) - Editar configurações
3. [helm/milvus-values-aws-eks.yaml](helm/milvus-values-aws-eks.yaml) - Editar configurações
4. Executar comandos Helm
5. [docs/pt-br/07-validacao.md](docs/pt-br/07-validacao.md) - Validar

### Para Troubleshooting
1. [docs/pt-br/08-troubleshooting.md](docs/pt-br/08-troubleshooting.md) - Problemas comuns
2. Logs: `kubectl logs -n NAMESPACE POD_NAME`
3. Eventos: `kubectl get events -n NAMESPACE`

## 📊 Namespaces e Componentes

### Airflow (namespace: airflow-test)
- API Server (Webserver)
- Scheduler
- DAG Processor
- Workers (Celery)
- Triggerer
- StatsD

**Dependências externas**:
- RDS PostgreSQL (metadata)
- Redis as Cache (message broker)
- S3 (logs, DAGs)

### Milvus (namespace: mmjc-test)
- MixCoordinator
- DataNode (2 réplicas)
- IndexNode (2 réplicas)
- QueryNode (3 réplicas)
- Proxy
- Etcd (3 pods - StatefulSet)
- Kafka (3 pods - StatefulSet)
- Zookeeper (3 pods - via Kafka subchart)
- MinIO (4 pods - StatefulSet)
- Attu UI
- MCP Milvus DB

**Dependências**:
- PVCs (EBS gp3)
- (Opcional) S3 em vez de MinIO

## 🔗 Links Externos Úteis

### Helm Charts
- [Apache Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/)
- [Milvus Helm Chart](https://github.com/zilliztech/milvus-helm)

### Documentação Oficial
- [Apache Airflow Docs](https://airflow.apache.org/docs/)
- [Milvus Docs](https://milvus.io/docs/)
- [AWS EKS Docs](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Ferramentas
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Docs](https://helm.sh/docs/)

## 📝 Como Usar Este Índice

1. **Primeira Migração?** Leia na ordem: README → Quickstart → Guias 01-08
2. **Referência Rápida?** Use MIGRATION_QUICKSTART.md
3. **Problema Específico?** Vá direto para 08-troubleshooting.md
4. **Configurar Helm?** Edite os arquivos em `helm/`

## 🆘 Precisa de Ajuda?

1. Verifique [docs/pt-br/08-troubleshooting.md](docs/pt-br/08-troubleshooting.md)
2. Veja logs: `kubectl logs -n NAMESPACE POD_NAME`
3. Veja eventos: `kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'`
4. Consulte documentação oficial dos componentes

---

**Última atualização**: 2025-10-30
**Projeto**: Migração IBM IKS → AWS EKS
**Namespaces**: `airflow-test` e `mmjc-test`
