data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "networking/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  route53_zone_id = data.terraform_remote_state.networking.outputs.route53_zone_id
}
