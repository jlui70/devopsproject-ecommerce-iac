resource "aws_rds_cluster_instance" "az1" {
  identifier         = "${var.aurora.cluster_identifier}-instance-1"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  availability_zone    = "${var.region}a"
  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = {
    Name = "${var.aurora.cluster_identifier}-instance-1"
  }
}

resource "aws_rds_cluster_instance" "az2" {
  identifier         = "${var.aurora.cluster_identifier}-instance-2"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  availability_zone    = "${var.region}b"
  db_subnet_group_name = aws_db_subnet_group.this.name

  tags = {
    Name = "${var.aurora.cluster_identifier}-instance-2"
  }
}
