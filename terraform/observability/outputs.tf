output "opensearch_domain_endpoint" {
  description = "Endpoint HTTPS do dominio OpenSearch — consumido pelas roles Ansible fluent-bit e metricbeat"
  value       = aws_opensearch_domain.logs.endpoint
}

output "opensearch_dashboards_url" {
  description = "URL do OpenSearch Dashboards"
  value       = "https://${aws_opensearch_domain.logs.endpoint}/_dashboards"
}

output "opensearch_domain_arn" {
  description = "ARN do dominio OpenSearch"
  value       = aws_opensearch_domain.logs.arn
}

output "opensearch_domain_name" {
  description = "Nome do dominio OpenSearch"
  value       = aws_opensearch_domain.logs.domain_name
}

output "fluentbit_index_name" {
  description = "Nome do indice OpenSearch para os logs do Fluent Bit"
  value       = "devopsproject-logs"
}
