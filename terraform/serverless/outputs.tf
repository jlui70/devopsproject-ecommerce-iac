output "rds_proxy_endpoint" {
  description = "Endpoint de escrita do RDS Proxy (PostgreSQL) — consumido por PRD-004"
  value       = aws_db_proxy.postgresql.endpoint
}

output "rds_proxy_readonly_endpoint" {
  description = "Endpoint read-only do RDS Proxy — consumido por PRD-004 (relatorios/leitura)"
  value       = aws_db_proxy_endpoint.readonly.endpoint
}

output "documentdb_cluster_endpoint" {
  description = "Endpoint de escrita do cluster DocumentDB — consumido por PRD-004"
  value       = aws_docdb_cluster.this.endpoint
}

output "email_notification_queue_url" {
  description = "URL da fila SQS EmailNotificationQueue — consumida por PRD-004"
  value       = aws_sqs_queue.email_notification.url
}

output "product_stock_queue_url" {
  description = "URL da fila SQS ProductStockQueue — consumida por PRD-004"
  value       = aws_sqs_queue.product_stock.url
}

output "invoice_queue_url" {
  description = "URL da fila SQS InvoiceQueue — consumida por PRD-004"
  value       = aws_sqs_queue.invoice.url
}

output "order_confirmed_topic_arn" {
  description = "ARN do topico SNS OrderConfirmedTopic — consumido por PRD-004 para publicacao"
  value       = aws_sns_topic.order_confirmed.arn
}

output "order_confirmed_lambda_url" {
  description = "Function URL (AWS_IAM) da Lambda orderConfirmedLambdaFunction — consumida por PRD-004"
  value       = aws_lambda_function_url.order_confirmed.function_url
}
