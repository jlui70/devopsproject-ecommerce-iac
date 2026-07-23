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
