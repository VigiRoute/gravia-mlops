output "vpc_id" {
  value = module.network.vpc_id
}

output "lake_bucket" {
  value = module.storage.lake_bucket
}

output "db_credentials_secret_arn" {
  value = module.mlops.db_credentials_secret_arn
}

output "database_endpoint" {
  value = module.storage.database_endpoint
}

output "ecr_serving_url" {
  value = module.compute.ecr_serving_url
}
