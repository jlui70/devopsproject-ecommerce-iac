# ADR-0012, Decisao 5: este secret manual e exclusivo do cluster Aurora de
# PRODUCAO (usado como fonte de auth do RDS Proxy). O cluster Aurora de STAGING
# (aws_rds_cluster.staging em rds.cluster.tf) usa `manage_master_user_password = true`
# e NAO precisa de um recurso de secret dedicado aqui — a AWS gera e gerencia o
# segredo automaticamente, com ARN proprio, exposto pelo atributo
# `aws_rds_cluster.staging[0].master_user_secret[0].secret_arn` (ver outputs.tf).
# Isso ja garante o isolamento de credenciais exigido pelo ADR (ARN distinto do
# secret de producao abaixo), sem duplicar logica de secret manual.

resource "aws_secretsmanager_secret" "aurora" {
  count = var.production_enabled ? 1 : 0

  name                    = "devopsproject/aurora/master-credentials"
  description             = "Credenciais master do Aurora PostgreSQL — usadas pelo RDS Proxy para autenticar clientes"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-aurora-master-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "aurora" {
  count = var.production_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.aurora[0].id

  secret_string = jsonencode({
    username = var.aurora.master_username
    password = var.aurora_master_password
    engine   = "aurora-postgresql"
  })
}
