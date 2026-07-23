resource "aws_db_subnet_group" "this" {
  name       = "devopsproject-aurora"
  subnet_ids = local.private_subnets_ids

  description = "Subnet group para Aurora PostgreSQL Serverless v2"

  tags = {
    Name = "devopsproject-aurora"
  }
}
