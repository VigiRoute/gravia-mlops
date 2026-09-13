# Bucket unique avec préfixes par couche (silver/, gold-artifacts/...), pas un bucket par couche :
# reproduit exactement la convention déjà en place côté MinIO en dev (cf.
# gravia/infra/docker-compose.yml, MINIO_BUCKET=gravia, cf. gravia/src/gravia/silver.py::object_key
# "silver/baac/...") — même structure de clés, bascule S3 sans réécrire le code applicatif.
resource "aws_s3_bucket" "lake" {
  bucket = "gravia-${var.environment}-lake"

  tags = {
    Name = "gravia-${var.environment}-lake"
  }
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# RDS PostgreSQL (Gold + métadonnées Airflow + backend-store MLflow, cf.
# gravia/infra/docker-compose.yml, service postgres) : indisponible sur LocalStack Community
# (403 "not included within your LocalStack license", constaté en testant — cf. terraform/
# variables.tf racine). Écrit pour la cible AWS réelle, appliqué seulement si
# `var.include_pro_only_services = true` (jamais contre LocalStack Community).
resource "aws_db_subnet_group" "main" {
  count      = var.include_pro_only_services ? 1 : 0
  name       = "gravia-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "gold" {
  count                  = var.include_pro_only_services ? 1 : 0
  identifier             = "gravia-${var.environment}-postgres"
  engine                 = "postgres"
  engine_version         = "17"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = "gravia"
  username               = "gravia"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [var.database_security_group_id]
  skip_final_snapshot    = true

  tags = {
    Name = "gravia-${var.environment}-postgres"
  }
}
