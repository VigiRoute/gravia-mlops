variable "environment" {
  description = "Environnement ciblé (dev, prod)."
  type        = string
}

variable "include_pro_only_services" {
  description = "Active ECR/EKS — indisponibles sur LocalStack Community (cf. terraform/variables.tf racine)."
  type        = bool
}

variable "public_subnet_id" {
  description = "Sous-réseau public pour le cluster EKS (module network)."
  type        = string
}
