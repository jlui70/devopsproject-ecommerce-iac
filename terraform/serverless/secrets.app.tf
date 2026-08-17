resource "random_password" "identity_key" {
  count = var.production_enabled ? 1 : 0

  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  count = var.production_enabled ? 1 : 0

  name                    = "devopsproject/app/secrets"
  description             = "Segredos da aplicacao devopsproject-ecommerce (connection strings, identity key)"
  recovery_window_in_days = 0

  tags = {
    Name = "devopsproject-app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  count = var.production_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.app[0].id

  secret_string = jsonencode({
    CONNECTIONSTRINGS__DEFAULT = join("", [
      "User ID=${var.aurora.master_username};",
      "Password=${var.aurora_master_password};",
      "Host=${aws_db_proxy.postgresql[0].endpoint};",
      "Port=5432;",
      "Database=${var.aurora.database_name};",
      "Include Error Detail=true"
    ])

    CONNECTIONSTRINGS__MONGO = join("", [
      "mongodb://",
      urlencode(jsondecode(aws_secretsmanager_secret_version.docdb[0].secret_string)["username"]), ":",
      urlencode(jsondecode(aws_secretsmanager_secret_version.docdb[0].secret_string)["password"]), "@",
      aws_docdb_cluster.this[0].endpoint,
      ":27017/admin?tls=true&tlsInsecure=true",
      "&connectTimeoutMS=10000&authSource=admin&authMechanism=SCRAM-SHA-1&retryWrites=false"
    ])

    IDENTITY__KEY                   = random_password.identity_key[0].result
    IDENTITY__ADMIN__USER__PASSWORD = var.app_identity_admin_password

    ORDER__LAMBDAPARAMS__FUNCTIONNAME = var.lambda.order_confirmed_function_name
  })
}

# ADR-0012 — segredo agregado da aplicacao para o ambiente staging, mesmo padrao
# de chaves do secret de producao acima (CONNECTIONSTRINGS__*, IDENTITY__*), mas
# apontando para os recursos -stg (Aurora sem RDS Proxy, DocumentDB -stg) e com
# credenciais isoladas (JWT key e senha admin proprias). E o contrato consumido
# pelo ExternalSecret do overlay staging/ no repo GitOps (ADR-0013), que espera
# a chave "devopsproject/app/secrets-stg".
data "aws_secretsmanager_secret_version" "aurora_staging_master" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  secret_id = aws_rds_cluster.staging[0].master_user_secret[0].secret_arn
}

resource "random_password" "identity_key_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "app_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                    = "devopsproject/app/secrets-stg"
  description             = "Segredos da aplicacao devopsproject-ecommerce - ambiente staging (ADR-0012)"
  recovery_window_in_days = 0

  tags = {
    Name        = "devopsproject-stg-app-secrets"
    Environment = "staging"
  }
}

resource "aws_secretsmanager_secret_version" "app_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.app_staging[0].id

  secret_string = jsonencode({
    # Sem RDS Proxy em staging (ADR-0012, Decisao 3) — conexao direta ao writer
    # endpoint do cluster Aurora -stg.
    CONNECTIONSTRINGS__DEFAULT = join("", [
      "User ID=${var.staging.aurora.master_username};",
      # Senha gerenciada pela AWS (manage_master_user_password) — o gerador padrao
      # da AWS exclui / @ " e espaco, mas NAO exclui ";" (separador de campo do
      # Npgsql/ADO.NET). Sem quoting, uma senha sorteada com ";" quebra a connection
      # string no meio (acha ao vivo em 2026-08-17, mesma classe do bug do Mongo
      # URI acima, ainda nao disparado por sorte do RNG). Quoting com aspas duplas +
      # duplicacao de aspas internas e o escaping padrao do Npgsql, seguro para
      # qualquer caractere na senha.
      "Password=\"${replace(jsondecode(data.aws_secretsmanager_secret_version.aurora_staging_master[0].secret_string)["password"], "\"", "\"\"")}\";",
      "Host=${aws_rds_cluster.staging[0].endpoint};",
      "Port=5432;",
      "Database=${var.staging.aurora.database_name};",
      "Include Error Detail=true"
    ])

    CONNECTIONSTRINGS__MONGO = join("", [
      "mongodb://",
      urlencode(jsondecode(aws_secretsmanager_secret_version.docdb_staging[0].secret_string)["username"]), ":",
      urlencode(jsondecode(aws_secretsmanager_secret_version.docdb_staging[0].secret_string)["password"]), "@",
      aws_docdb_cluster.staging[0].endpoint,
      ":27017/admin?tls=true&tlsInsecure=true",
      "&connectTimeoutMS=10000&authSource=admin&authMechanism=SCRAM-SHA-1&retryWrites=false"
    ])

    IDENTITY__KEY                   = random_password.identity_key_staging[0].result
    IDENTITY__ADMIN__USER__PASSWORD = var.staging_app_identity_admin_password

    # Lambda nao e duplicada para staging (fora do escopo do ADR-0012) — reaproveita
    # a mesma function de producao.
    ORDER__LAMBDAPARAMS__FUNCTIONNAME = var.lambda.order_confirmed_function_name
  })
}
