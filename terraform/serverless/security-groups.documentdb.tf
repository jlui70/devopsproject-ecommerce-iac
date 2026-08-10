resource "aws_security_group" "documentdb" {
  count = var.production_enabled ? 1 : 0

  name        = "devopsproject-documentdb"
  description = "SG para DocumentDB: ingress 27017 de control-plane, worker e self"
  vpc_id      = local.vpc_id

  tags = {
    Name = "devopsproject-documentdb"
  }
}

resource "aws_security_group_rule" "documentdb_ingress_control_plane" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.documentdb[0].id
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = local.control_plane_sg_id
  description              = "DocumentDB from control plane"
}

resource "aws_security_group_rule" "documentdb_ingress_worker" {
  count = var.production_enabled ? 1 : 0

  security_group_id        = aws_security_group.documentdb[0].id
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = local.worker_sg_id
  description              = "DocumentDB from workers"
}

resource "aws_security_group_rule" "documentdb_ingress_self" {
  count = var.production_enabled ? 1 : 0

  security_group_id = aws_security_group.documentdb[0].id
  type              = "ingress"
  from_port         = 27017
  to_port           = 27017
  protocol          = "tcp"
  self              = true
  description       = "DocumentDB self"
}

resource "aws_security_group_rule" "documentdb_egress_all" {
  count = var.production_enabled ? 1 : 0

  security_group_id = aws_security_group.documentdb[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Egress total"
}
