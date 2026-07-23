resource "aws_route53_record" "site" {
  zone_id = local.route53_zone_id
  name    = var.site.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.production.domain_name
    zone_id                = aws_cloudfront_distribution.production.hosted_zone_id
    evaluate_target_health = false
  }
}
