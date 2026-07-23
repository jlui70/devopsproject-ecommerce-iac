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
}
