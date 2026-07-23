resource "aws_lb" "apiserver" {
  name               = "devopsproject-prod-cp-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.networking.outputs.private_subnets_ids

  tags = { Name = "devopsproject-prod-cp-nlb" }
}
