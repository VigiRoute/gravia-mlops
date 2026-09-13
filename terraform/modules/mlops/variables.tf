variable "environment" {
  description = "Environnement ciblé (dev, prod)."
  type        = string
}

variable "db_password" {
  description = "Mot de passe PostgreSQL à stocker (cf. module storage)."
  type        = string
  sensitive   = true
  default     = ""
}
