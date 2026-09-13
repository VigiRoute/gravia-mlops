# Secrets Manager : cible réelle des identifiants qui vivent dans `.env` en dev côté gravia
# (cf. gravia/CLAUDE.md, "Variables d'environnement" — jamais committés, .env en dev / Secrets
# Manager en cible réelle). Disponible sur LocalStack Community (cf. terraform/variables.tf
# racine) : seul module entièrement applicable et vérifié tel quel, RDS/ECR/EKS mis à part.
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "gravia-${var.environment}-db-credentials"
  description = "Identifiants PostgreSQL (Gold, Airflow, backend-store MLflow)"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "gravia"
    password = var.db_password
  })
}
