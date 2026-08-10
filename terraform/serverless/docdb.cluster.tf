resource "aws_docdb_cluster" "this" {
  count = var.production_enabled ? 1 : 0

  cluster_identifier = var.docdb.cluster_identifier
  engine             = "docdb"
  engine_version     = var.docdb.engine_version

  master_username = jsondecode(aws_secretsmanager_secret_version.docdb[0].secret_string)["username"]
  master_password = jsondecode(aws_secretsmanager_secret_version.docdb[0].secret_string)["password"]

  db_subnet_group_name            = aws_docdb_subnet_group.this[0].name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this[0].name
  vpc_security_group_ids          = [aws_security_group.documentdb[0].id]

  storage_encrypted = true

  backup_retention_period      = var.docdb.backup_retention_period
  preferred_backup_window      = var.docdb.preferred_backup_window
  preferred_maintenance_window = var.docdb.preferred_maintenance_window

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true

  deletion_protection = false

  tags = {
    Name = var.docdb.cluster_identifier
  }
}

# ADR-0012: cluster DocumentDB isolado do ambiente staging. Reaproveita a subnet
# group e o parameter group (TLS/audit/profiler) do cluster de producao — mesma
# family docdb5.0, sem necessidade de recursos dedicados — e o mesmo Security
# Group `documentdb` (SG ja autoriza os workers compartilhados). Credenciais em
# secret proprio `-stg` (secrets.documentdb.tf), distinto do secret de producao.
#
# ADR-0012 (state key separada): subnet group, parameter group e Security Group
# sao "donos" do state de producao (aws_*.this, gateados por
# var.production_enabled) — quando esta stack e aplicada isoladamente contra a
# state key de staging (production_enabled=false), esses recursos nao existem
# localmente. local.documentdb_subnet_group_name / local.postgresql... resolvem
# via data.terraform_remote_state.serverless_production nesse caso (ver
# data.serverless-production.tf).
resource "aws_docdb_cluster" "staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  cluster_identifier = var.staging.docdb.cluster_identifier
  engine             = "docdb"
  engine_version     = var.staging.docdb.engine_version

  master_username = jsondecode(aws_secretsmanager_secret_version.docdb_staging[0].secret_string)["username"]
  master_password = jsondecode(aws_secretsmanager_secret_version.docdb_staging[0].secret_string)["password"]

  db_subnet_group_name            = local.documentdb_subnet_group_name
  db_cluster_parameter_group_name = local.documentdb_cluster_parameter_group_name
  vpc_security_group_ids          = [local.documentdb_security_group_id]

  storage_encrypted = true

  backup_retention_period      = var.staging.docdb.backup_retention_period
  preferred_backup_window      = var.staging.docdb.preferred_backup_window
  preferred_maintenance_window = var.staging.docdb.preferred_maintenance_window

  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  skip_final_snapshot = true

  deletion_protection = false

  tags = {
    Name        = var.staging.docdb.cluster_identifier
    Environment = "staging"
  }
}
