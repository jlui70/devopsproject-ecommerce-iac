# ADR-0023: a stack `cicd` depende exclusivamente de `server` — os ARNs dos
# repositorios ECR usados no escopo das policies de push/promocao. Nao ha
# nenhuma dependencia do ALB nem do CloudFront, e e' por isso que esta stack
# pode ser aplicada no Estagio 2, junto com `serverless` e `observability`,
# em vez de ficar presa dentro de `site` (ultima stack do deploy).
data "terraform_remote_state" "server" {
  backend = "s3"
  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "server/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  ecr_repo_arns = [
    for url in values(data.terraform_remote_state.server.outputs.ecr_repository_urls) :
    "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${join("/", slice(split("/", url), 1, length(split("/", url))))}"
  ]
}
