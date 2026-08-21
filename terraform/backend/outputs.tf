output "state_bucket_id" {
  description = "ID do bucket S3 de estado remoto"
  value       = aws_s3_bucket.this.id
}

output "state_lock_table_name" {
  description = "Nome da tabela DynamoDB de locking"
  value       = aws_dynamodb_table.this.name
}

output "ansible_ssm_bucket_id" {
  description = "Bucket de transporte da conexao SSM do Ansible (ansible/group_vars/all.yml)"
  value       = aws_s3_bucket.ansible_ssm.id
}

output "patch_logs_bucket_id" {
  description = "Bucket de saida dos relatorios de patch do SSM (stack server)"
  value       = aws_s3_bucket.patch_logs.id
}
