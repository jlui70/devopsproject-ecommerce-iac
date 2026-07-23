resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.cluster.name}-key"
  public_key = tls_private_key.this.public_key_openssh

  tags = { Name = "${var.cluster.name}-key" }
}
