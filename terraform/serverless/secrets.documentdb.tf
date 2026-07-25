resource "random_password" "docdb" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "docdb" {
  name                    = "devopsproject/docdb/master-user-secret"
  description             = "Senha do usuario master do DocumentDB (devopsproject)"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-docdb-master-secret"
  }
}

resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id = aws_secretsmanager_secret.docdb.id

  secret_string = jsonencode({
    username = "devopsprojectAdmin"
    password = random_password.docdb.result
  })
}
