terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Backend para armazenar state no S3
  backend "s3" {
    bucket         = "itau-terraform-state-dev"
    key            = "eks/airflow-milvus/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "airflow-milvus-migration"
      ManagedBy   = "terraform"
      Source      = "ibm-iks"
      Target      = "aws-eks"
    }
  }
}

# Dados do EKS existente
data "aws_eks_cluster" "existing" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.existing.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.existing.token
  }
}

# Módulos
module "vpc" {
  source = "../../modules/vpc"

  count = var.create_new_vpc ? 1 : 0

  vpc_name             = "${var.project_name}-vpc"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "rds_postgres" {
  source = "../../modules/rds"

  identifier              = "${var.project_name}-airflow-postgres"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_encrypted       = true
  db_name                 = "airflow"
  username                = var.db_username
  vpc_id                  = var.create_new_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids              = var.create_new_vpc ? module.vpc[0].private_subnet_ids : var.existing_subnet_ids
  allowed_security_groups = [data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id]
}

module "redis_cache" {
  source = "../../modules/elasticache"

  cluster_id              = "${var.project_name}-airflow-redis"
  engine                  = "redis"
  node_type               = var.redis_node_type
  num_cache_nodes         = 1
  vpc_id                  = var.create_new_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  subnet_ids              = var.create_new_vpc ? module.vpc[0].private_subnet_ids : var.existing_subnet_ids
  allowed_security_groups = [data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id]
}

module "s3_buckets" {
  source = "../../modules/s3"

  buckets = [
    {
      name          = "${var.project_name}-airflow-logs"
      versioning    = true
      lifecycle_days = 90
    },
    {
      name          = "${var.project_name}-airflow-dags"
      versioning    = true
      lifecycle_days = 0
    },
    {
      name          = "${var.project_name}-milvus-data"
      versioning    = true
      lifecycle_days = 0
    }
  ]
}

# Namespaces no EKS
resource "kubernetes_namespace" "airflow_test" {
  metadata {
    name = "airflow-test"
    labels = {
      name        = "airflow-test"
      environment = "test"
      migration   = "ibm-iks-to-aws-eks"
    }
  }
}

resource "kubernetes_namespace" "milvus" {
  metadata {
    name = "milvus-dev"
    labels = {
      name        = "milvus-dev"
      environment = "dev"
      migration   = "ibm-iks-to-aws-eks"
    }
  }
}

# Secrets para Airflow (criar manualmente ou via External Secrets Operator)
# Ver docs/pt-br/03-configurar-secrets.md para instruções

# Output de conexões
output "rds_endpoint" {
  value       = module.rds_postgres.endpoint
  description = "Endpoint do RDS Postgres para Airflow"
}

output "redis_endpoint" {
  value       = module.redis_cache.endpoint
  description = "Endpoint do Redis as Cache para Airflow"
}

output "s3_buckets" {
  value = {
    logs  = module.s3_buckets.bucket_names[0]
    dags  = module.s3_buckets.bucket_names[1]
    milvus = module.s3_buckets.bucket_names[2]
  }
  description = "Nomes dos buckets S3 criados"
}
