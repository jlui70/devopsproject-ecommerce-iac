resource "aws_security_group" "alb" {
  name        = "${var.cluster.name}-alb"
  description = "Security group - application ALB, accepts 443 only from CloudFront managed prefix list"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = { Name = "${var.cluster.name}-alb" }
}

# Ingress: TCP 443 only from CloudFront managed prefix list
resource "aws_security_group_rule" "alb_ingress_https_cloudfront" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "HTTPS only from CloudFront managed prefix list"
}

# Egress: unrestricted outbound
resource "aws_security_group_rule" "alb_egress_all" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Unrestricted egress"
}
