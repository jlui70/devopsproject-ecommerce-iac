resource "aws_nat_gateway" "this" {
  for_each = toset(var.vpc.availability_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = { Name = "${var.vpc.name}-nat-${each.key}" }

  depends_on = [aws_internet_gateway.this]
}
