output "lake_bucket" {
  value = aws_s3_bucket.lake.bucket
}

output "database_endpoint" {
  value       = var.include_pro_only_services ? aws_db_instance.gold[0].endpoint : null
  description = "null tant que include_pro_only_services=false (RDS non créée, cf. main.tf)."
}
