variable "region" {
  description = "Região AWS onde a stack é provisionada"
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

variable "cluster" {
  description = "Parâmetros do cluster Kubernetes"
  type = object({
    name       = string
    domain     = string
    pod_subnet = string
  })
  nullable = false
}

variable "control_plane" {
  description = "Configuração do ASG de control plane"
  type = object({
    instance_type = string
    ebs_size_gb   = number
    asg = object({
      min     = number
      desired = number
      max     = number
    })
  })
  nullable = false
}

variable "worker" {
  description = "Configuração do ASG de workers"
  type = object({
    instance_type = string
    ebs_size_gb   = number
    asg = object({
      min     = number
      desired = number
      max     = number
    })
  })
  nullable = false
}

variable "ecr_repositories" {
  description = "Lista de nomes dos repositórios ECR"
  type        = list(string)
  nullable    = false
}

variable "ssm_patch" {
  description = "Configuração do SSM Patch Manager"
  type = object({
    bucket_name = string
    log_prefix  = string
    schedule    = string
  })
  nullable = false
}

variable "ansible_ssm_bucket" {
  description = "Nome do bucket S3 de transporte do Ansible via SSM"
  type        = string
  nullable    = false
}
