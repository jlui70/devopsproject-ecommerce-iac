resource "aws_security_group" "lambda" {
  name        = "devopsproject-lambda"
  description = "SG para Lambdas em VPC: egress total para acesso a proxy, docdb, secrets, sns e sqs"
  vpc_id      = local.vpc_id

  tags = {
    Name = "devopsproject-lambda"
  }
}

resource "aws_security_group_rule" "lambda_egress_all" {
  security_group_id = aws_security_group.lambda.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Egress total"
}

resource "aws_security_group_rule" "postgresql_ingress_lambda" {
  security_group_id        = aws_security_group.postgresql.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  description              = "PostgreSQL from lambda"
}

resource "aws_security_group_rule" "documentdb_ingress_lambda" {
  security_group_id        = aws_security_group.documentdb.id
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  description              = "DocumentDB from lambda"
}
