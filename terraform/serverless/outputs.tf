output "rds_proxy_endpoint" {
  description = "Endpoint de escrita do RDS Proxy (PostgreSQL) — consumido por PRD-004"
  value       = try(aws_db_proxy.postgresql[0].endpoint, null)
}

output "rds_proxy_readonly_endpoint" {
  description = "Endpoint read-only do RDS Proxy — consumido por PRD-004 (relatorios/leitura)"
  value       = try(aws_db_proxy_endpoint.readonly[0].endpoint, null)
}

output "documentdb_cluster_endpoint" {
  description = "Endpoint de escrita do cluster DocumentDB — consumido por PRD-004"
  value       = try(aws_docdb_cluster.this[0].endpoint, null)
}

output "email_notification_queue_url" {
  description = "URL da fila SQS EmailNotificationQueue — consumida por PRD-004"
  value       = try(aws_sqs_queue.email_notification[0].url, null)
}

output "product_stock_queue_url" {
  description = "URL da fila SQS ProductStockQueue — consumida por PRD-004"
  value       = try(aws_sqs_queue.product_stock[0].url, null)
}

output "invoice_queue_url" {
  description = "URL da fila SQS InvoiceQueue — consumida por PRD-004"
  value       = try(aws_sqs_queue.invoice[0].url, null)
}

output "order_confirmed_topic_arn" {
  description = "ARN do topico SNS OrderConfirmedTopic — consumido por PRD-004 para publicacao"
  value       = try(aws_sns_topic.order_confirmed[0].arn, null)
}

output "order_confirmed_lambda_url" {
  description = "Function URL (AWS_IAM) da Lambda orderConfirmedLambdaFunction — consumida por PRD-004"
  value       = try(aws_lambda_function_url.order_confirmed[0].function_url, null)
}

# --- ADR-0012 (state key separada): outputs dos recursos compartilhados entre
# producao e staging (SGs, subnet groups, parameter group do DocumentDB). So
# existem quando production_enabled=true; consumidos via
# data.terraform_remote_state.serverless_production por esta mesma stack
# aplicada com production_enabled=false (ver data.serverless-production.tf).

output "postgresql_security_group_id" {
  description = "ID do Security Group compartilhado do Aurora PostgreSQL (producao e staging) — consumido via remote state cross-reference quando esta stack e aplicada com production_enabled=false (ADR-0012)"
  value       = try(aws_security_group.postgresql[0].id, null)
}

output "documentdb_security_group_id" {
  description = "ID do Security Group compartilhado do DocumentDB (producao e staging) — consumido via remote state cross-reference quando esta stack e aplicada com production_enabled=false (ADR-0012)"
  value       = try(aws_security_group.documentdb[0].id, null)
}

output "aurora_db_subnet_group_name" {
  description = "Nome do DB Subnet Group compartilhado do Aurora (producao e staging) — consumido via remote state cross-reference quando esta stack e aplicada com production_enabled=false (ADR-0012)"
  value       = try(aws_db_subnet_group.this[0].name, null)
}

output "documentdb_subnet_group_name" {
  description = "Nome do Subnet Group compartilhado do DocumentDB (producao e staging) — consumido via remote state cross-reference quando esta stack e aplicada com production_enabled=false (ADR-0012)"
  value       = try(aws_docdb_subnet_group.this[0].name, null)
}

output "documentdb_cluster_parameter_group_name" {
  description = "Nome do Cluster Parameter Group compartilhado do DocumentDB (producao e staging) — consumido via remote state cross-reference quando esta stack e aplicada com production_enabled=false (ADR-0012). Compartilhamento identificado durante a implementacao (nao listado explicitamente no ADR-0012 original), tratado com o mesmo padrao de cross-state dos SGs/subnet-groups por necessidade de consistencia"
  value       = try(aws_docdb_cluster_parameter_group.this[0].name, null)
}

# --- ADR-0012: outputs do ambiente staging (dados/mensageria isolados) ---
# Todos vazios/null quando var.staging esta desabilitado (ex.: aplicado com
# production.tfvars). Contrato consumido pelo ADR-0013 (ConfigMap/Secret K8s
# do namespace staging).

output "staging_aurora_writer_endpoint" {
  description = "Endpoint de escrita (writer) do cluster Aurora staging — sem RDS Proxy, conexao direta (ADR-0012)"
  value       = try(aws_rds_cluster.staging[0].endpoint, null)
}

output "staging_aurora_master_user_secret_arn" {
  description = "ARN do segredo gerenciado (manage_master_user_password) do Aurora staging — distinto do secret de producao"
  value       = try(aws_rds_cluster.staging[0].master_user_secret[0].secret_arn, null)
}

output "staging_documentdb_cluster_endpoint" {
  description = "Endpoint de escrita do cluster DocumentDB staging"
  value       = try(aws_docdb_cluster.staging[0].endpoint, null)
}

output "staging_documentdb_master_user_secret_arn" {
  description = "ARN do segredo do usuario master do DocumentDB staging (secrets.documentdb.tf)"
  value       = try(aws_secretsmanager_secret.docdb_staging[0].arn, null)
}

output "staging_app_secret_arn" {
  description = "ARN do segredo agregado da aplicacao (devopsproject/app/secrets-stg) consumido pelo ExternalSecret do overlay staging/ (secrets.app.tf)"
  value       = try(aws_secretsmanager_secret.app_staging[0].arn, null)
}

output "staging_email_notification_queue_url" {
  description = "URL da fila SQS EmailNotificationQueue-stg — consumida pelo namespace staging"
  value       = try(aws_sqs_queue.email_notification_staging[0].url, null)
}

output "staging_product_stock_queue_url" {
  description = "URL da fila SQS ProductStockQueue-stg — consumida pelo namespace staging"
  value       = try(aws_sqs_queue.product_stock_staging[0].url, null)
}

output "staging_invoice_queue_url" {
  description = "URL da fila SQS InvoiceQueue-stg — consumida pelo namespace staging"
  value       = try(aws_sqs_queue.invoice_staging[0].url, null)
}
