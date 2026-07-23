resource "aws_route_table" "private" {
  for_each = toset(var.vpc.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = { Name = "${var.vpc.name}-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each = toset(var.vpc.availability_zones)

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
