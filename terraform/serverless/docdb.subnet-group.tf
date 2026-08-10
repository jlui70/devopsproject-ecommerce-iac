resource "aws_docdb_subnet_group" "this" {
  count = var.production_enabled ? 1 : 0

  name       = "devopsproject-docdb"
  subnet_ids = local.private_subnets_ids

  description = "Subnet group para DocumentDB 5.0"

  tags = {
    Name = "devopsproject-docdb"
  }
}
