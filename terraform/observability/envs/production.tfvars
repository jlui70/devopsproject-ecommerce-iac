region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

opensearch = {
  domain_name              = "devopsproject-logs"
  engine_version           = "OpenSearch_2.17"
  instance_type            = "t3.medium.search"
  instance_count           = 1
  ebs_volume_size          = 20
  ebs_volume_type          = "gp3"
  ebs_throughput           = 125
  ebs_iops                 = 3000
  tls_security_policy      = "Policy-Min-TLS-1-2-2019-07"
  master_user_name         = "admin"
  audit_log_retention_days = 14
}

# opensearch_master_password: NAO incluir aqui — injetar via:
# export TF_VAR_opensearch_master_password="<senha>"
