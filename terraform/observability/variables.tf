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

variable "opensearch" {
  description = "Configuracao do dominio OpenSearch de observabilidade"
  type = object({
    domain_name              = string
    engine_version           = string
    instance_type            = string
    instance_count           = number
    ebs_volume_size          = number
    ebs_volume_type          = string
    ebs_throughput           = number
    ebs_iops                 = number
    tls_security_policy      = string
    master_user_name         = string
    audit_log_retention_days = number
  })
  nullable = false
}

variable "opensearch_master_password" {
  description = "Senha do master user (admin) — sensivel; injetar via TF_VAR_, nao commitar"
  type        = string
  sensitive   = true
  nullable    = false
}
