resource "opensearch_roles_mapping" "all_access" {
  role_name     = "all_access"
  backend_roles = [local.worker_instance_role_arn]
  users         = [var.opensearch.master_user_name]

  depends_on = [aws_opensearch_domain.logs]
}
