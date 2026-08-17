variable "region" {
  description = "Regiao AWS onde a stack e provisionada"
  type        = string
  nullable    = false
}

variable "assume_role" {
  description = "Configuracao de assume role do Terraform"
  type = object({
    role_arn    = string
    external_id = string
  })
  nullable = false
}

variable "production_enabled" {
  description = "Habilita os recursos de producao desta stack. true em envs/production.tfvars, false em envs/staging.tfvars — permite aplicar cada ambiente contra sua propria state key sem recriar o outro (ADR-0012)."
  type        = bool
  nullable    = false
}

variable "aurora" {
  description = "Parametros do cluster Aurora PostgreSQL Serverless v2"
  type = object({
    cluster_identifier           = string
    database_name                = string
    master_username              = string
    min_capacity                 = number
    max_capacity                 = number
    backup_retention_period      = number
    preferred_backup_window      = string
    preferred_maintenance_window = string
  })
  nullable = false
}

variable "docdb" {
  description = "Parametros do cluster DocumentDB"
  type = object({
    cluster_identifier           = string
    engine_version               = string
    instance_class               = string
    backup_retention_period      = number
    preferred_backup_window      = string
    preferred_maintenance_window = string
  })
  nullable = false
}

variable "sqs" {
  description = "Nomes das filas SQS e respectivas DLQs"
  type = object({
    email_notification_queue_name = string
    email_notification_dlq_name   = string
    product_stock_queue_name      = string
    product_stock_dlq_name        = string
    invoice_queue_name            = string
    invoice_dlq_name              = string
  })
  nullable = false
}

variable "sns" {
  description = "Parametros do topico SNS"
  type = object({
    order_confirmed_topic_name = string
  })
  nullable = false
}

variable "lambda" {
  description = "Parametros das funcoes Lambda e da Layer"
  type = object({
    order_confirmed_function_name = string
    report_job_function_name      = string
    layer_source_path             = string
    order_confirmed_source_path   = string
    report_job_source_path        = string
    scheduler_expression          = string
  })
  nullable = false
}

variable "ses" {
  description = "Parametros do dominio SES"
  type = object({
    domain              = string
    mail_from_subdomain = string
    template_name       = string
    improvmx = object({
      mx_priority_10 = string
      mx_priority_20 = string
      spf_include    = string
    })
  })
  nullable = false
}

variable "app" {
  description = "Recursos da aplicacao (S3, DocumentDB CA)"
  type = object({
    s3_bucket               = string
    documentdb_ca_cert_path = string
  })
  nullable = false
}

variable "aurora_master_password" {
  description = "Senha master do cluster Aurora PostgreSQL. Injetar via: export TF_VAR_aurora_master_password='<senha>'"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "app_identity_admin_password" {
  description = "Senha do usuario admin da aplicacao (producao). Nunca em .tfvars — injetar via: export TF_VAR_app_identity_admin_password='<senha>'"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "staging_app_identity_admin_password" {
  description = "Senha do usuario admin da aplicacao (staging, ADR-0012). Nunca em .tfvars — injetar via: export TF_VAR_staging_app_identity_admin_password='<senha>'. Nao usada quando staging desabilitado (mesmo padrao de aurora_master_password)."
  type        = string
  sensitive   = true
  nullable    = false
}

# ADR-0012: bloco unico e opcional com toda a camada de dados/mensageria do
# ambiente staging (Aurora, DocumentDB, SQS). Nulo em producao (envs/production.tfvars
# nao declara esta variavel), preenchido em envs/staging.tfvars. `default = null` e a
# unica excecao proposital a regra "sem default nas variaveis" deste projeto: aqui o
# default nao carrega nenhum valor de configuracao, apenas torna o bloco opcional para
# que o var-file de producao permaneca inalterado, conforme pedido pelo ADR-0012.
variable "staging" {
  description = "Parametros da camada de dados/mensageria isolada do ambiente staging (ADR-0012). Nulo quando o ambiente staging nao esta habilitado nesta aplicacao (ex.: producao)."
  type = object({
    enabled = bool

    aurora = object({
      cluster_identifier           = string
      database_name                = string
      master_username              = string
      min_capacity                 = number
      max_capacity                 = number
      seconds_until_auto_pause     = number
      backup_retention_period      = number
      preferred_backup_window      = string
      preferred_maintenance_window = string
    })

    docdb = object({
      cluster_identifier           = string
      engine_version               = string
      instance_class               = string
      backup_retention_period      = number
      preferred_backup_window      = string
      preferred_maintenance_window = string
    })

    sqs = object({
      email_notification_queue_name = string
      email_notification_dlq_name   = string
      product_stock_queue_name      = string
      product_stock_dlq_name        = string
      invoice_queue_name            = string
      invoice_dlq_name              = string
    })
  })
  default = null
}
