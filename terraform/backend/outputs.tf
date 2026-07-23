output "state_bucket_id" {
  description = "ID do bucket S3 de estado remoto"
  value       = aws_s3_bucket.this.id
}

output "state_lock_table_name" {
  description = "Nome da tabela DynamoDB de locking"
  value       = aws_dynamodb_table.this.name
}
