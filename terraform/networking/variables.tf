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

variable "vpc" {
  description = "Configurações da VPC e subnets"
  type = object({
    name                 = string
    cidr                 = string
    availability_zones   = list(string)
    public_subnet_cidrs  = map(string)
    private_subnet_cidrs = map(string)
  })
  nullable = false
}

variable "route53" {
  description = "Hosted zone pública do e-commerce"
  type = object({
    zone_name = string
  })
  nullable = false
}
