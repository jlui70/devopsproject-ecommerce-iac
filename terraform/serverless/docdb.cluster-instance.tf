resource "aws_docdb_cluster_instance" "this" {
  identifier         = "${var.docdb.cluster_identifier}-instance-1"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.docdb.instance_class

  tags = {
    Name = "${var.docdb.cluster_identifier}-instance-1"
  }
}
