region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

cluster = {
  name       = "ecommerce-devopsproject-cluster"
  domain     = "ecommerce-devopsproject.com"
  pod_subnet = "10.244.0.0/16"
}

control_plane = {
  instance_type = "t3.medium"
  ebs_size_gb   = 20
  asg           = { min = 2, desired = 2, max = 2 }
}

worker = {
  instance_type = "t3.small"
  ebs_size_gb   = 20
  asg           = { min = 5, desired = 5, max = 5 }
}
# Teste ao vivo do ADR-0022 em 2026-08-17: subiu de 5 para 6 temporariamente para
# validar o auto-join via user_data (ver ec2.instances.worker-bootstrap.tf) — node
# novo entrou sozinho, Ready em ~90s, sem nenhuma execucao de Ansible. Revertido
# para 5 (dimensionamento correto para replicaCount:2 nos 6 servicos, ADR-0004)
# apos confirmar.

ecr_repositories = [
  "devopsproject/prod/health-checker",
  "devopsproject/prod/notificator",
  "devopsproject/prod/order",
  "devopsproject/prod/invoice-generator",
  "devopsproject/prod/identity-server",
  "devopsproject/prod/main"
]

ssm_patch = {
  bucket_name = "devopsproject-production-logs"
  log_prefix  = "patching-logs"
  schedule    = "cron(*/30 * * * ? *)"
}

ansible_ssm_bucket = "devopsproject-ecommerce-ansible-ssm"
