output "vpc_id" {
  description = "ID da VPC principal"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC principal"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs dos NAT Gateways (um por AZ)"
  value       = [for nat in aws_nat_gateway.this : nat.id]
}

output "public_subnets_ids" {
  description = "IDs das subnets públicas"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnets_ids" {
  description = "IDs das subnets privadas"
  value       = [for s in aws_subnet.private : s.id]
}

output "route53_zone_id" {
  description = "ID da Hosted Zone Route53"
  value       = aws_route53_zone.this.zone_id
}

output "route53_zone_name_servers" {
  description = "4 name servers do Route 53 — configurar como Custom DNS no painel do Namecheap (Domain List → Manage → Nameservers → Custom DNS)"
  value       = aws_route53_zone.this.name_servers
}
