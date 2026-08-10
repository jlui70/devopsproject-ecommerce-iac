resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repositories)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE" # ADR-0020: trava sobrescrita de qualquer tag (sha-*/release-*)
  force_delete         = true

  tags = { Name = each.value }
}
