resource "aws_ses_domain_identity" "this" {
  count = var.production_enabled ? 1 : 0

  domain = var.ses.domain
}

resource "aws_ses_domain_dkim" "this" {
  count = var.production_enabled ? 1 : 0

  domain = aws_ses_domain_identity.this[0].domain
}

resource "aws_route53_record" "ses_verification" {
  count = var.production_enabled ? 1 : 0

  zone_id = local.route53_zone_id
  name    = "_amazonses.${var.ses.domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.this[0].verification_token]
}

resource "aws_route53_record" "ses_dkim" {
  count   = var.production_enabled ? 3 : 0
  zone_id = local.route53_zone_id
  name    = "${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}._domainkey.${var.ses.domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.this[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}
