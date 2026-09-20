# Bascule dev (LocalStack) / cible (AWS réel) par variable, pas par code dupliqué (cf.
# docs/Deploiement_GRAVIA_MLOps.md, "Pourquoi LocalStack") : même provider, seuls endpoint et
# identifiants changent selon
# `var.localstack_endpoint`. Vide (défaut en cible réelle) => aucun bloc `endpoints`, le provider
# utilise les vrais endpoints AWS et les vraies credentials (variables AWS_* standard).
terraform {
  required_version = ">= 1.16"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.64.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Identifiants factices acceptés par LocalStack (n'importe quelle valeur non vide) ; ignorés
  # côté LocalStack qui ne vérifie pas de vraies credentials AWS. Sans `var.localstack_endpoint`
  # (cible réelle), ces valeurs sont ignorées par le provider au profit des vraies variables
  # d'environnement AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY.
  access_key = var.localstack_endpoint != "" ? "test" : null
  secret_key = var.localstack_endpoint != "" ? "test" : null

  skip_credentials_validation = var.localstack_endpoint != ""
  skip_metadata_api_check     = var.localstack_endpoint != ""
  skip_requesting_account_id  = var.localstack_endpoint != ""

  # S3 : LocalStack sert les buckets sans le DNS virtual-hosted-style qu'AWS réel utilise
  # (bucket.s3.amazonaws.com) — nécessite le style "chemin" (s3.amazonaws.com/bucket).
  s3_use_path_style = var.localstack_endpoint != ""

  dynamic "endpoints" {
    for_each = var.localstack_endpoint != "" ? [1] : []
    content {
      s3             = var.localstack_endpoint
      ec2            = var.localstack_endpoint
      iam            = var.localstack_endpoint
      sts            = var.localstack_endpoint
      kms            = var.localstack_endpoint
      secretsmanager = var.localstack_endpoint
      ecr            = var.localstack_endpoint
      rds            = var.localstack_endpoint
      eks            = var.localstack_endpoint
    }
  }
}
