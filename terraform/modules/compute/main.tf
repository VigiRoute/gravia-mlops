# IAM : seule partie de ce module réellement applicable sur LocalStack Community (iam disponible,
# cf. terraform/variables.tf racine) — rôle que les nœuds EKS assumeraient en cible réelle.
resource "aws_iam_role" "eks_node" {
  name = "gravia-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# ECR (images gravia-serving/gravia-airflow, cf. gravia/infra/*/Dockerfile) et EKS (cluster K8s
# cible, cf. gravia-mlops/k8s pour la démonstration réelle via `kind` à la place) : indisponibles
# sur LocalStack Community (403 "not included within your LocalStack license", constaté en
# testant — cf. terraform/variables.tf racine). Écrits pour la cible AWS réelle, appliqués
# seulement si `var.include_pro_only_services = true`.
#
# EKS n'est de toute façon jamais appliqué dans ce dépôt, licence Pro ou non : sa réalité
# opérationnelle (Deployment/Service/scaling/auto-guérison) est déjà vérifiée pour de vrai via
# `kind` (cf. k8s/, CLAUDE.md « Pourquoi kind ») — ce bloc documente la cible AWS, il ne remplace
# pas cette vérification.
resource "aws_ecr_repository" "serving" {
  count                = var.include_pro_only_services ? 1 : 0
  name                 = "gravia-${var.environment}-serving"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository" "airflow" {
  count                = var.include_pro_only_services ? 1 : 0
  name                 = "gravia-${var.environment}-airflow"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_eks_cluster" "main" {
  count    = var.include_pro_only_services ? 1 : 0
  name     = "gravia-${var.environment}-eks"
  role_arn = aws_iam_role.eks_node.arn

  vpc_config {
    subnet_ids = [var.public_subnet_id]
  }
}
