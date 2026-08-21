terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # ADR-0023: a camada de dados de staging (ADR-0012) usa um WORKSPACE, nao uma
  # troca manual de state key. O workspace `default` grava em
  # serverless/terraform.tfstate (a key abaixo) e o workspace `staging` grava em
  # env:/staging/serverless/terraform.tfstate — o prefixo `env:` e' o padrao do
  # backend S3 para workspaces. Isso preserva data.terraform_remote_state
  # .serverless_production (data.serverless-production.tf), que continua lendo a
  # key de producao sem alteracao, e elimina o `terraform init -reconfigure` de
  # ida e volta que o runbook exigia (antiga Fase 7.6).
  #
  #   terraform workspace select -or-create staging
  #   terraform apply -var-file=envs/production.tfvars -var-file=envs/staging.tfvars
  #   terraform workspace select default
  backend "s3" {
    bucket       = "devopsproject-terraform-state-692430448478"
    key          = "serverless/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
