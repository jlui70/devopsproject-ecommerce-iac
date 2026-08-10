resource "aws_ses_template" "order_confirmed" {
  count = var.production_enabled ? 1 : 0

  name    = var.ses.template_name
  subject = "Importante: seu pedido {{OrderId}} foi confirmado"
  html    = "<p>Olá! Seu pedido <strong>{{OrderId}}</strong> foi confirmado. Nota fiscal: {{InvoiceNumber}}.</p>"
  text    = "Olá! Seu pedido {{OrderId}} foi confirmado. Nota fiscal: {{InvoiceNumber}}."
}
