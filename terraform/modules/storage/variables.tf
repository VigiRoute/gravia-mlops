variable "environment" {
  description = "Environnement ciblé (dev, prod)."
  type        = string
}

variable "include_pro_only_services" {
  description = "Active la RDS PostgreSQL — indisponible sur LocalStack Community (cf. terraform/variables.tf racine)."
  type        = bool
}

variable "private_subnet_ids" {
  description = "Sous-réseaux privés (2 AZ minimum, exigence RDS) pour la RDS (module network)."
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Groupe de sécurité de la base (module network)."
  type        = string
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (RDS). Jamais en dur — cf. terraform.tfvars.example."
  type        = string
  sensitive   = true
  default     = ""
}
