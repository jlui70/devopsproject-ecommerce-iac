resource "aws_db_subnet_group" "this" {
  count = var.production_enabled ? 1 : 0

  name       = "devopsproject-aurora"
  subnet_ids = local.private_subnets_ids

  description = "Subnet group para Aurora PostgreSQL Serverless v2"

  tags = {
    Name = "devopsproject-aurora"
  }
}
