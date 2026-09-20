variable "environment" {
  description = "Environnement ciblé (dev, prod) — utilisé dans le nommage des ressources (cf. gravia/CLAUDE.md, convention gravia-{env}-{ressource})."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Région AWS ciblée."
  type        = string
  default     = "eu-west-1"
}

variable "localstack_endpoint" {
  description = "Endpoint LocalStack (ex. http://localhost:4566). Vide = cible AWS réelle."
  type        = string
  default     = "http://localhost:4566"
}

# Distinction cruciale, constatée en testant (cf. docs/Deploiement_GRAVIA_MLOps.md, "Pourquoi
# LocalStack") : LocalStack
# **Community** (gratuit) ne supporte ni ECR ni RDS (403 "not included within your LocalStack
# license" constaté en interrogeant directement l'API) — seuls S3/IAM/EC2/KMS/STS/Secrets Manager
# le sont. Les ressources RDS/ECR/EKS restent écrites (exigence CDC : architecture cible AWS
# intégralement documentée) mais ne sont appliquées que si ce flag est activé — jamais contre
# LocalStack Community, à activer seulement contre AWS réel (ou LocalStack Pro, non utilisé ici).
variable "include_pro_only_services" {
  description = "Active RDS/ECR/EKS — indisponibles sur LocalStack Community (403 license). À activer uniquement contre AWS réel."
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (RDS + Secrets Manager). Jamais en dur — cf. terraform.tfvars.example."
  type        = string
  sensitive   = true
  default     = "changeme-local-demo"
}
