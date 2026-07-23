data "aws_acm_certificate" "this" {
  domain      = var.site.domain
  statuses    = ["ISSUED"]
  most_recent = true
}
