# O domínio é registrado no Namecheap. O Terraform cria a Hosted Zone aqui.
# Após o apply, copiar os 4 name servers do output route53_zone_name_servers
# e configurar como Custom DNS no painel do Namecheap:
#   Domain List → ecommerce-devopsproject.com → Nameservers → Custom DNS
resource "aws_route53_zone" "this" {
  name = var.route53.zone_name

  tags = { Name = var.route53.zone_name }
}
