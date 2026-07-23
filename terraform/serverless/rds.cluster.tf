resource "aws_rds_cluster" "this" {
  cluster_identifier = var.aurora.cluster_identifier
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "16.8"

  database_name   = var.aurora.database_name
  master_username = var.aurora.master_username

  manage_master_user_password = true

  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.postgresql.id]

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
