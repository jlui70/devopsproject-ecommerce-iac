resource "aws_ssm_parameter" "opensearch_master_password" {
  name        = "/devopsproject/opensearch/master-password"
  description = "Senha master do OpenSearch — lida pelo Ansible para configurar o Metricbeat"
  type        = "SecureString"
  value       = var.opensearch_master_password
  overwrite   = true

  tags = {
    Name = "devopsproject-opensearch-master-password"
  }
}
