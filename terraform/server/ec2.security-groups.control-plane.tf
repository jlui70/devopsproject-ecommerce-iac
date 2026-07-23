# SG do control plane - criado sem regras de cross-referencia inline
# para evitar dependencia circular com o SG dos workers.
# As regras de cross-referencia sao declaradas via aws_security_group_rule abaixo.
resource "aws_security_group" "control_plane" {
  name        = "${var.cluster.name}-control-plane"
  description = "Security group - control plane nodes of cluster ${var.cluster.name}"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = { Name = "${var.cluster.name}-control-plane" }
}

# Ingress: all traffic between control plane nodes (self)
resource "aws_security_group_rule" "control_plane_ingress_self" {
  security_group_id = aws_security_group.control_plane.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  description       = "All traffic between control plane nodes"
}

# Ingress: all traffic from worker nodes (cross-reference)
resource "aws_security_group_rule" "control_plane_ingress_from_worker" {
  security_group_id        = aws_security_group.control_plane.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.worker.id
  description              = "All traffic from worker nodes to control plane"
}

# Egress: unrestricted outbound
resource "aws_security_group_rule" "control_plane_egress_all" {
  security_group_id = aws_security_group.control_plane.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Unrestricted egress"
}

# Ingress: NLB health checks and intra-VPC access to kube-apiserver (port 6443)
# NLB does not have a SG — health checks originate from NLB node IPs within the VPC CIDR
resource "aws_security_group_rule" "control_plane_ingress_apiserver_vpc" {
  security_group_id = aws_security_group.control_plane.id
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [data.terraform_remote_state.networking.outputs.vpc_cidr]
  description       = "kube-apiserver - NLB health checks and intra-VPC access"
}
