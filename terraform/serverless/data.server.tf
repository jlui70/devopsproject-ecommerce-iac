data "terraform_remote_state" "server" {
  backend = "s3"

  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "server/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  control_plane_sg_id = data.terraform_remote_state.server.outputs.control_plane_security_group_id
  worker_sg_id        = data.terraform_remote_state.server.outputs.worker_security_group_id
}
