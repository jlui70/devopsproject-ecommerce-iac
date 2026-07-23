data "aws_lb" "cluster" {
  name = var.site.alb_name
}
