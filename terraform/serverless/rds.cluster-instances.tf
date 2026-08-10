resource "aws_rds_cluster_instance" "az1" {
  count = var.production_enabled ? 1 : 0

  identifier         = "${var.aurora.cluster_identifier}-instance-1"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version

  availability_zone    = "${var.region}a"
  db_subnet_group_name = aws_db_subnet_group.this[0].name

  tags = {
    Name = "${var.aurora.cluster_identifier}-instance-1"
  }
}

resource "aws_rds_cluster_instance" "az2" {
  count = var.production_enabled ? 1 : 0

  identifier         = "${var.aurora.cluster_identifier}-instance-2"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version

  availability_zone    = "${var.region}b"
  db_subnet_group_name = aws_db_subnet_group.this[0].name

  tags = {
    Name = "${var.aurora.cluster_identifier}-instance-2"
  }
}

# ADR-0012: unica instancia single-AZ do cluster Aurora staging (sem par 1a/1b —
# HA nao e requisito de staging, Decisao 1).
resource "aws_rds_cluster_instance" "staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  identifier         = "${var.staging.aurora.cluster_identifier}-instance-1"
  cluster_identifier = aws_rds_cluster.staging[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.staging[0].engine
  engine_version     = aws_rds_cluster.staging[0].engine_version

  availability_zone    = "${var.region}a"
  db_subnet_group_name = local.aurora_db_subnet_group_name

  tags = {
    Name        = "${var.staging.aurora.cluster_identifier}-instance-1"
    Environment = "staging"
  }
}
