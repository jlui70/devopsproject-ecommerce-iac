data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "devopsproject-terraform-state-692430448478"
    key    = "networking/terraform.tfstate"
    region = "us-east-1"
  }
}
