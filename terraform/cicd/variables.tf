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

variable "github" {
  description = "Configuracoes do repositorio GitHub para OIDC e IAM roles de CI/CD"
  type = object({
    repo            = string
    oidc_thumbprint = string
  })
  nullable = false
}
