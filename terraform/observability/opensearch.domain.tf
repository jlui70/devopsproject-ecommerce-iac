resource "aws_opensearch_domain" "logs" {
  domain_name    = var.opensearch.domain_name
  engine_version = var.opensearch.engine_version

  cluster_config {
    instance_type  = var.opensearch.instance_type
    instance_count = var.opensearch.instance_count
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.opensearch.ebs_volume_type
    volume_size = var.opensearch.ebs_volume_size
    throughput  = var.opensearch.ebs_throughput
    iops        = var.opensearch.ebs_iops
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = var.opensearch.tls_security_policy
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.opensearch.master_user_name
      master_user_password = var.opensearch_master_password
    }
  }

  access_policies = data.aws_iam_policy_document.opensearch.json

  log_publishing_options {
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.opensearch_audit.arn}:*"
    log_type                 = "AUDIT_LOGS"
    enabled                  = true
  }

  depends_on = [aws_cloudwatch_log_resource_policy.opensearch_audit]

  tags = {
    Name = var.opensearch.domain_name
  }
}
