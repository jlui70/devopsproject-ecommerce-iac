# Registros de e-mail no apex para recebimento via ImprovMX forwarding
# → encaminha support@ecommerce-devopsproject.com para devops.oyy1@gmail.com
# Ref: ADR-0010 — Decisão de e-mail (Opção 1: ImprovMX)
#
# PASSO MANUAL OBRIGATÓRIO antes do apply desta stack:
#   1. Criar conta em https://improvmx.com
#   2. Adicionar domínio ecommerce-devopsproject.com
#   3. Criar regra: support@ → devops.oyy1@gmail.com
#   4. Confirmar que os valores mx_priority_10/mx_priority_20/spf_include
#      nos tfvars correspondem exatamente ao exibido no painel do ImprovMX.

resource "aws_route53_record" "improvmx_mx" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = var.ses.domain
  type    = "MX"
  ttl     = 600
  records = [
    "10 ${var.ses.improvmx.mx_priority_10}",
    "20 ${var.ses.improvmx.mx_priority_20}",
  ]
}

# SPF no apex: único registro combinando SES (envio) + ImprovMX (autenticação de forwarding)
# Dois registros SPF separados no mesmo nome causariam falha de validação (RFC 7208).
resource "aws_route53_record" "apex_spf" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = var.ses.domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com include:${var.ses.improvmx.spf_include} ~all"]
}
