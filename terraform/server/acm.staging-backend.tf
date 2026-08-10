# Emenda ADR-0011/ADR-0014 (2026-08-10) — corrige achado ao vivo no primeiro deploy
# real: nao existe certificado wildcard "*.ecommerce-devopsproject.com" na conta (o
# certificado de producao em acm.tf cobre SOMENTE "ecommerce-devopsproject.com").
# O ADR-0014 e o overlay staging/ingress.yml (ADR-0013) assumiam esse wildcard pra
# cobrir "staging.ecommerce-devopsproject.com" sem precisar de ACM novo — nao e
# verdade. Corrigido com um certificado dedicado, minimo, exclusivo pro backend de
# staging. O Ingress de staging usa um ALB proprio (load-balancer-name distinto do
# de producao, sem group.name compartilhado), entao nao ha SNI/multi-cert em jogo —
# um certificado single-domain e suficiente.

resource "aws_acm_certificate" "staging_backend" {
  domain_name       = "staging.${var.cluster.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "staging.${var.cluster.domain}" }
}

resource "aws_route53_record" "staging_backend_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.staging_backend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.terraform_remote_state.networking.outputs.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "staging_backend" {
  certificate_arn         = aws_acm_certificate.staging_backend.arn
  validation_record_fqdns = [for r in aws_route53_record.staging_backend_acm_validation : r.fqdn]
}

output "staging_backend_acm_certificate_arn" {
  description = "ARN do certificado ACM dedicado a staging.<dominio> — usado no Ingress do overlay staging/ (ADR-0013/0014)"
  value       = aws_acm_certificate_validation.staging_backend.certificate_arn
}
