variable "region" {
  description = "Região AWS"
  type        = string
  nullable    = false
}

variable "assume_role" {
  description = "Configuração de assume role do Terraform"
  type = object({
    role_arn    = string
    external_id = string
  })
  nullable = false
}

variable "state_backend" {
  description = "Configurações do backend de estado remoto"
  type = object({
    bucket_name = string
    table_name  = string
  })
  nullable = false
}

# ADR-0023: buckets de apoio consumidos por outras stacks e pelo Ansible.
variable "support_buckets" {
  description = "Buckets de apoio criados junto com o backend de estado"
  type = object({
    ansible_ssm_name = string
    patch_logs_name  = string
  })
  nullable = false
}
