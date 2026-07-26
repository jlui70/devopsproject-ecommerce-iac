resource "aws_secretsmanager_secret" "aurora" {
  name                    = "devopsproject/aurora/master-credentials"
  description             = "Credenciais master do Aurora PostgreSQL — usadas pelo RDS Proxy para autenticar clientes"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-aurora-master-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id

  secret_string = jsonencode({
    username = var.aurora.master_username
    password = var.aurora_master_password
    engine   = "aurora-postgresql"
  })
}
