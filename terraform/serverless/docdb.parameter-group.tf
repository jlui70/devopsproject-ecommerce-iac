resource "aws_docdb_cluster_parameter_group" "this" {
  count = var.production_enabled ? 1 : 0

  name        = "devopsproject-docdb5"
  family      = "docdb5.0"
  description = "Parameter group para DocumentDB 5.0 com TLS, audit e profiler"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "audit_logs"
    value = "enabled"
  }

  parameter {
    name  = "profiler"
    value = "enabled"
  }

  tags = {
    Name = "devopsproject-docdb5"
  }
}
