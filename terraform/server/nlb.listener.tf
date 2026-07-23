resource "aws_lb_listener" "apiserver" {
  load_balancer_arn = aws_lb.apiserver.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apiserver.arn
  }

  tags = { Name = "devopsproject-prod-cp-listener" }
}
