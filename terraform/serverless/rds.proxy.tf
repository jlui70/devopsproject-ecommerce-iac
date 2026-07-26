resource "aws_iam_role" "rds_proxy" {
  name = "devopsproject-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_proxy_secret" {
  name = "devopsproject-rds-proxy-secret-policy"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.aurora.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_db_proxy" "postgresql" {
  name                   = "devopsproject-postgresql-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 300
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.postgresql.id]
  vpc_subnet_ids         = local.private_subnets_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.aurora.arn
  }

  tags = {
    Name = "devopsproject-postgresql-proxy"
  }

  depends_on = [aws_iam_role_policy.rds_proxy_secret]
}

resource "aws_db_proxy_default_target_group" "postgresql" {
  db_proxy_name = aws_db_proxy.postgresql.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "postgresql" {
  db_cluster_identifier = aws_rds_cluster.this.cluster_identifier
  db_proxy_name         = aws_db_proxy.postgresql.name
  target_group_name     = aws_db_proxy_default_target_group.postgresql.name
}
