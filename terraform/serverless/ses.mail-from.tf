resource "aws_ses_domain_mail_from" "this" {
  count = var.production_enabled ? 1 : 0

  domain           = aws_ses_domain_identity.this[0].domain
  mail_from_domain = "${var.ses.mail_from_subdomain}.${var.ses.domain}"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = aws_ses_domain_mail_from.this[0].mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = aws_ses_domain_mail_from.this[0].mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}
