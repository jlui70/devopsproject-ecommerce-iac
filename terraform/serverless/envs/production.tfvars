region = "us-east-1"

# ADR-0012: state key separada por ambiente. production_enabled=true faz esta
# aplicacao criar/possuir os recursos de producao (Aurora, DocumentDB, SQS, SNS,
# Lambda, SES, S3, RDS Proxy, SGs e subnet groups compartilhados). Aplicar
# sempre contra a state key default (serverless/terraform.tfstate) — ver
# outputs.tf e data.serverless-production.tf para o mecanismo de
# compartilhamento de SGs/subnet-groups com o state de staging.
production_enabled = true

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

aurora = {
  cluster_identifier           = "devopsproject-aurora"
  database_name                = "devopsprojectEcommerce"
  master_username              = "devopsprojectAdmin"
  min_capacity                 = 0.5
  max_capacity                 = 1.0
  backup_retention_period      = 7
  preferred_backup_window      = "01:00-02:00"
  preferred_maintenance_window = "sun:05:00-sun:06:00"
}

docdb = {
  cluster_identifier           = "devopsproject-docdb"
  engine_version               = "5.0"
  instance_class               = "db.t3.medium"
  backup_retention_period      = 7
  preferred_backup_window      = "01:00-02:00"
  preferred_maintenance_window = "sun:03:00-sun:04:00"
}

sqs = {
  email_notification_queue_name = "EmailNotificationQueue"
  email_notification_dlq_name   = "EmailNotificationQueueDlq"
  product_stock_queue_name      = "ProductStockQueue"
  product_stock_dlq_name        = "ProductStockQueueDlq"
  invoice_queue_name            = "InvoiceQueue"
  invoice_dlq_name              = "InvoiceQueueDlq"
}

sns = {
  order_confirmed_topic_name = "OrderConfirmedTopic"
}

lambda = {
  order_confirmed_function_name = "orderConfirmedLambdaFunction"
  report_job_function_name      = "reportJobLambdaFunction"
  layer_source_path             = "lambdas/layer/build"
  order_confirmed_source_path   = "lambdas/order-confirmed/build"
  report_job_source_path        = "lambdas/report-job/build"
  scheduler_expression          = "rate(1 minutes)"
}

ses = {
  domain              = "ecommerce-devopsproject.com"
  mail_from_subdomain = "bounce"
  template_name       = "order-confirmed-template"
  improvmx = {
    mx_priority_10 = "mx1.improvmx.com"
    mx_priority_20 = "mx2.improvmx.com"
    spf_include    = "spf.improvmx.com"
  }
}

app = {
  s3_bucket               = "devopsproject-app-files"
  documentdb_ca_cert_path = "certs/documentdb-ca.pem"
}
# app_identity_admin_password: NAO incluir aqui — injetar via:
# export TF_VAR_app_identity_admin_password="<senha>"
