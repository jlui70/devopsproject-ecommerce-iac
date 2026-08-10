resource "aws_security_group" "lambda" {
  count = var.production_enabled ? 1 : 0

  name        = "devopsproject-lambda"
  description = "SG para Lambdas em VPC: egress total para acesso a proxy, docdb, secrets, sns e sqs"
  vpc_id      = local.vpc_id

  tags = {
    Name = "devopsproject-lambda"
  }
}

resource "aws_security_group_rule" "lambda_egress_all" {
  count = var.production_enabled ? 1 : 0

  security_group_id = aws_security_group.lambda[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Egress total"
}

resource "aws_security_group_rule" "postgresql_ingress_lambda" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.postgresql[0].id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda[0].id
  description              = "PostgreSQL from lambda"
}

resource "aws_security_group_rule" "documentdb_ingress_lambda" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.documentdb[0].id
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda[0].id
  description              = "DocumentDB from lambda"
}
