resource "aws_subnet" "public" {
  for_each = var.vpc.public_subnet_cidrs

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = { Name = "${var.vpc.name}-public-${each.key}" }
}
