resource "random_password" "identity_key" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "devopsproject/app/secrets"
  description             = "Segredos da aplicacao devopsproject-ecommerce (connection strings, identity key)"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    CONNECTIONSTRINGS__DEFAULT = join("", [
      "User ID=${var.aurora.master_username};",
      "Password=${var.aurora_master_password};",
      "Host=${aws_db_proxy.postgresql.endpoint};",
      "Port=5432;",
      "Database=${var.aurora.database_name};",
      "Include Error Detail=true"
    ])

    CONNECTIONSTRINGS__MONGO = join("", [
      "mongodb://",
      jsondecode(aws_secretsmanager_secret_version.docdb.secret_string)["username"], ":",
      jsondecode(aws_secretsmanager_secret_version.docdb.secret_string)["password"], "@",
      aws_docdb_cluster.this.endpoint,
      ":27017/admin?ssl=true&sslInvalidHostNameAllowed=true",
      "&connectTimeoutMS=10000&authSource=admin&authMechanism=SCRAM-SHA-1"
    ])

    IDENTITY__KEY                   = random_password.identity_key.result
    IDENTITY__ADMIN__USER__PASSWORD = var.app.identity_admin_password

    ORDER__LAMBDAPARAMS__FUNCTIONNAME = var.lambda.order_confirmed_function_name
  })
}
