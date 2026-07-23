resource "aws_eip" "nat" {
  for_each = toset(var.vpc.availability_zones)

  domain = "vpc"

  tags = { Name = "${var.vpc.name}-nat-eip-${each.key}" }
}
