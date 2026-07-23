resource "aws_subnet" "private" {
  for_each = var.vpc.private_subnet_cidrs

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.vpc.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
