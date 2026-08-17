data "terraform_remote_state" "server" {
  backend = "s3"
  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "server/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  worker_instance_role_arn  = data.terraform_remote_state.server.outputs.worker_instance_role_arn
  worker_instance_role_name = element(split("/", data.terraform_remote_state.server.outputs.worker_instance_role_arn), length(split("/", data.terraform_remote_state.server.outputs.worker_instance_role_arn)) - 1)

  # Fluent Bit roda como DaemonSet em TODOS os nodes, inclusive control plane — sem
  # essa role no mapping do OpenSearch, os pods de Fluent Bit nos nodes de control
  # plane recebem 403 security_exception (indices:data/write/bulk) e nunca ficam
  # Ready. Achado ao vivo em 2026-08-17: opensearch.roles-mapping.tf só tinha a role
  # do worker desde a criação do arquivo.
  control_plane_instance_role_arn = data.terraform_remote_state.server.outputs.control_plane_instance_role_arn
}
