resource "random_password" "docdb" {
  count = var.production_enabled ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "docdb" {
  count = var.production_enabled ? 1 : 0

  name                    = "devopsproject/docdb/master-user-secret"
  description             = "Senha do usuario master do DocumentDB (devopsproject)"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-docdb-master-secret"
  }
}

resource "aws_secretsmanager_secret_version" "docdb" {
  count = var.production_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.docdb[0].id

  secret_string = jsonencode({
    username = "devopsprojectAdmin"
    password = random_password.docdb[0].result
  })
}

# ADR-0012: segredo DocumentDB isolado do ambiente staging (Decisao 5, Opcao A) —
# ARN distinto do secret de producao acima; IAM de staging (ADR-0014) so recebe
# GetSecretValue neste ARN, nunca no de producao.
resource "random_password" "docdb_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "docdb_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                    = "devopsproject/docdb-stg/master-user-secret"
  description             = "Senha do usuario master do DocumentDB staging (devopsproject-stg, ADR-0012)"
  recovery_window_in_days = 0

  tags = {
    Name        = "devopsproject-stg-docdb-master-secret"
    Environment = "staging"
  }
}

resource "aws_secretsmanager_secret_version" "docdb_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.docdb_staging[0].id

  secret_string = jsonencode({
    username = "devopsprojectAdmin"
    password = random_password.docdb_staging[0].result
  })
}
