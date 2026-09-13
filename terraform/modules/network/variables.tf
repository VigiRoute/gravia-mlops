variable "environment" {
  description = "Environnement ciblé (dev, prod) — cf. gravia/CLAUDE.md, convention de nommage."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  type        = string
  default     = "10.20.0.0/16"
}
