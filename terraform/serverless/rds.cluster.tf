resource "aws_rds_cluster" "this" {
  count = var.production_enabled ? 1 : 0

  cluster_identifier = var.aurora.cluster_identifier
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "16.8"

  database_name   = var.aurora.database_name
  master_username = var.aurora.master_username
  master_password = var.aurora_master_password

  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.postgresql[0].id]

  backup_retention_period      = var.aurora.backup_retention_period
  preferred_backup_window      = var.aurora.preferred_backup_window
  preferred_maintenance_window = var.aurora.preferred_maintenance_window

  skip_final_snapshot = true
  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora.min_capacity
    max_capacity = var.aurora.max_capacity
  }

  tags = {
    Name = var.aurora.cluster_identifier
  }

  lifecycle {
    ignore_changes = [availability_zones]
  }
}

# ADR-0012: cluster Aurora isolado do ambiente staging. Reaproveita a mesma subnet
# group e o mesmo Security Group `postgresql` do cluster de producao (SGs ja
# autorizam o trafego dos workers compartilhados — sem SG dedicado a staging na
# camada AWS, conforme o ADR). Sem RDS Proxy: a app staging conecta direto no
# writer endpoint (Decisao 3, Opcao A). Senha nao e definida aqui — usa
# `manage_master_user_password = true`, que gera um segredo proprio no Secrets
# Manager (ARN distinto do secret manual de producao em secrets.aurora.tf).
#
# ADR-0012 (state key separada): subnet group e Security Group sao "donos" do
# state de producao (aws_db_subnet_group.this / aws_security_group.postgresql,
# gateados por var.production_enabled) — quando esta stack e aplicada
# isoladamente contra a state key de staging (production_enabled=false), esses
# recursos nao existem localmente. local.aurora_db_subnet_group_name /
# local.postgresql_security_group_id resolvem via
# data.terraform_remote_state.serverless_production nesse caso (ver
# data.serverless-production.tf).
resource "aws_rds_cluster" "staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  cluster_identifier = var.staging.aurora.cluster_identifier
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "16.8"

  database_name   = var.staging.aurora.database_name
  master_username = var.staging.aurora.master_username

  manage_master_user_password = true

  storage_encrypted = true

  db_subnet_group_name   = local.aurora_db_subnet_group_name
  vpc_security_group_ids = [local.postgresql_security_group_id]

  backup_retention_period      = var.staging.aurora.backup_retention_period
  preferred_backup_window      = var.staging.aurora.preferred_backup_window
  preferred_maintenance_window = var.staging.aurora.preferred_maintenance_window

  skip_final_snapshot = true
  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity             = var.staging.aurora.min_capacity
    max_capacity             = var.staging.aurora.max_capacity
    seconds_until_auto_pause = var.staging.aurora.seconds_until_auto_pause
  }

  tags = {
    Name        = var.staging.aurora.cluster_identifier
    Environment = "staging"
  }

  lifecycle {
    ignore_changes = [availability_zones]
  }
}
