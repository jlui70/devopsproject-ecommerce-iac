resource "aws_lb_target_group" "apiserver" {
  name        = "devopsproject-prod-cp-tg"
  port        = 6443
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  preserve_client_ip = false

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "devopsproject-prod-cp-tg" }
}
