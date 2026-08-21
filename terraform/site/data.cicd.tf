# ADR-0023: o provider OIDC do GitHub e as roles de ECR (staging/prod/backend)
# migraram para a stack `cicd`, aplicada no Estagio 2. As duas roles de frontend
# continuam aqui porque escopam permissoes sobre recursos desta stack
# (aws_s3_bucket.site/staging/frontend_staging e as distribuicoes CloudFront) —
# nao ha como move-las sem afrouxar o escopo para "*". Isso tambem e' honesto do
# ponto de vista de ordem: um deploy de frontend nao tem o que fazer antes do
# bucket de destino existir.
data "terraform_remote_state" "cicd" {
  backend = "s3"
  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "cicd/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  github_oidc_provider_arn = data.terraform_remote_state.cicd.outputs.github_oidc_provider_arn
}
