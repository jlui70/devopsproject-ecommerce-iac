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
  asg           = { min = 6, desired = 6, max = 6 } # teste temporario ADR-0022, ver nota abaixo
}
# Teste ao vivo do ADR-0022 em 2026-08-17: subiu de 5 para 6 de proposito, so' para
# confirmar que o node novo entra sozinho via user_data (sem rodar Ansible depois).
# Reverter para 5 assim que confirmado.

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
