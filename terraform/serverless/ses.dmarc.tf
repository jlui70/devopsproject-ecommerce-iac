resource "aws_route53_record" "ses_dmarc" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = "_dmarc.${var.ses.domain}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none;"]
}
