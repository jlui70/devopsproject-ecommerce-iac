# SG dos workers - criado sem regras de cross-referencia inline
# para evitar dependencia circular com o SG do control plane.
# As regras de cross-referencia sao declaradas via aws_security_group_rule abaixo.
resource "aws_security_group" "worker" {
  name        = "${var.cluster.name}-worker"
  description = "Security group - worker nodes of cluster ${var.cluster.name}"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = { Name = "${var.cluster.name}-worker" }
}

# Ingress: all traffic between worker nodes (self)
resource "aws_security_group_rule" "worker_ingress_self" {
  security_group_id = aws_security_group.worker.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  description       = "All traffic between worker nodes"
}

# Ingress: all traffic from control plane nodes (cross-reference)
resource "aws_security_group_rule" "worker_ingress_from_control_plane" {
  security_group_id        = aws_security_group.worker.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.control_plane.id
  description              = "All traffic from control plane to worker nodes"
}

# Egress: unrestricted outbound
resource "aws_security_group_rule" "worker_egress_all" {
  security_group_id = aws_security_group.worker.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Unrestricted egress"
}
