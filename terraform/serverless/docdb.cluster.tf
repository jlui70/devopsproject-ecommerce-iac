resource "aws_docdb_cluster" "this" {
  cluster_identifier = var.docdb.cluster_identifier
  engine             = "docdb"
  engine_version     = var.docdb.engine_version

  master_username = jsondecode(aws_secretsmanager_secret_version.docdb.secret_string)["username"]
  master_password = jsondecode(aws_secretsmanager_secret_version.docdb.secret_string)["password"]

  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.documentdb.id]

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
