data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "networking/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id              = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnets_ids = data.terraform_remote_state.networking.outputs.private_subnets_ids
  route53_zone_id     = data.terraform_remote_state.networking.outputs.route53_zone_id
}
