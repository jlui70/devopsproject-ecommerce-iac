resource "aws_docdb_cluster_instance" "this" {
  count = var.production_enabled ? 1 : 0

  identifier         = "${var.docdb.cluster_identifier}-instance-1"
  cluster_identifier = aws_docdb_cluster.this[0].id
  instance_class     = var.docdb.instance_class

  tags = {
    Name = "${var.docdb.cluster_identifier}-instance-1"
  }
}

# ADR-0012: unica instancia single-AZ, sem replica, do cluster DocumentDB staging
# (Decisao 2, Opcao A).
resource "aws_docdb_cluster_instance" "staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  identifier         = "${var.staging.docdb.cluster_identifier}-instance-1"
  cluster_identifier = aws_docdb_cluster.staging[0].id
  instance_class     = var.staging.docdb.instance_class

  tags = {
    Name        = "${var.staging.docdb.cluster_identifier}-instance-1"
    Environment = "staging"
  }
}
