# Emenda ADR-0011 (2026-08-10) — corrige achado ao vivo no primeiro deploy real:
# o certificado ACM de producao (terraform/server/acm.tf) cobre SOMENTE
# "ecommerce-devopsproject.com" — nao existe wildcard SAN "*.ecommerce-devopsproject.com"
# como o ADR-0010/a implementacao original desta emenda assumiram. Reutilizar
# data.aws_acm_certificate.this para app-staging.* falha com
# InvalidViewerCertificate no CloudFront.
#
# Corrigido com um certificado ACM dedicado e minimo, exclusivo para o subdominio do
# frontend staging — nao mexe no certificado de producao (evita revalidacao/downtime
# de algo ja em uso por producao/ALB). Mesmo padrao de validacao DNS de
# terraform/server/acm.tf.

resource "aws_acm_certificate" "frontend_staging" {
  domain_name       = var.site.frontend_staging_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = var.site.frontend_staging_domain }
}

resource "aws_route53_record" "frontend_staging_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend_staging.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = local.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "frontend_staging" {
  certificate_arn         = aws_acm_certificate.frontend_staging.arn
  validation_record_fqdns = [for r in aws_route53_record.frontend_staging_acm_validation : r.fqdn]
}
