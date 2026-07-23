resource "aws_db_proxy_endpoint" "readonly" {
  db_proxy_name          = aws_db_proxy.postgresql.name
  db_proxy_endpoint_name = "devopsproject-postgresql-proxy-readonly"
  vpc_subnet_ids         = local.private_subnets_ids
  vpc_security_group_ids = [aws_security_group.postgresql.id]
  target_role            = "READ_ONLY"

  tags = {
    Name = "devopsproject-postgresql-proxy-readonly"
  }
}
