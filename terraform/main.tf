module "network" {
  source = "./modules/network"

  environment = var.environment
}

module "storage" {
  source = "./modules/storage"

  environment                = var.environment
  include_pro_only_services  = var.include_pro_only_services
  private_subnet_ids         = module.network.private_subnet_ids
  database_security_group_id = module.network.database_security_group_id
  db_password                = var.db_password
}

module "compute" {
  source = "./modules/compute"

  environment               = var.environment
  include_pro_only_services = var.include_pro_only_services
  public_subnet_id          = module.network.public_subnet_id
}

module "mlops" {
  source = "./modules/mlops"

  environment = var.environment
  db_password = var.db_password
}
