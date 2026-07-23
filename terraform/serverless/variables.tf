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
  description = "Recursos de aplicacao (bucket S3 e caminho do CA do DocumentDB)"
  type = object({
    s3_bucket               = string
    documentdb_ca_cert_path = string
  })
  nullable = false
}
