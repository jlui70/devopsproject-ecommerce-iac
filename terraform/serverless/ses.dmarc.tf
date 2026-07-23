resource "aws_route53_record" "ses_dmarc" {
  zone_id = local.route53_zone_id
  name    = "_dmarc.${var.ses.domain}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none;"]
}
