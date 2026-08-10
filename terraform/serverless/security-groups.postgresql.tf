resource "aws_security_group" "postgresql" {
  count = var.production_enabled ? 1 : 0

  name        = "devopsproject-postgresql"
  description = "SG para Aurora PostgreSQL: ingress 5432 de control-plane, worker e self"
  vpc_id      = local.vpc_id

  tags = {
    Name = "devopsproject-postgresql"
  }
}

resource "aws_security_group_rule" "postgresql_ingress_control_plane" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.postgresql[0].id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = local.control_plane_sg_id
  description              = "PostgreSQL from control plane"
}

resource "aws_security_group_rule" "postgresql_ingress_worker" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.postgresql[0].id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = local.worker_sg_id
  description              = "PostgreSQL from workers"
}

resource "aws_security_group_rule" "postgresql_ingress_self" {
  count = var.production_enabled ? 1 : 0

  security_group_id = aws_security_group.postgresql[0].id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  self              = true
  description       = "PostgreSQL self"
}

resource "aws_security_group_rule" "postgresql_egress_all" {
  count = var.production_enabled ? 1 : 0

  security_group_id = aws_security_group.postgresql[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Egress total"
}
