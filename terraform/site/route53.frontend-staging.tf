# Emenda ADR-0011 (2026-08-10): alias A record para a distribuicao CloudFront dedicada do
# frontend estatico de staging (cloudfront.frontend-staging.tf). Nao confundir com o registro
# de staging.ecommerce-devopsproject.com (backend/API interno, ADR-0014, gerenciado no stack
# `server`/`networking` — nao neste arquivo).

resource "aws_route53_record" "frontend_staging" {
  zone_id = local.route53_zone_id
  name    = var.site.frontend_staging_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend_staging.domain_name
    zone_id                = aws_cloudfront_distribution.frontend_staging.hosted_zone_id
    evaluate_target_health = false
  }
}
