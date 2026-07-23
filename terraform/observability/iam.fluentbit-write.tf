resource "aws_iam_role_policy" "fluentbit_opensearch_write" {
  name = "devopsproject-fluentbit-opensearch-write"
  role = local.worker_instance_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FluentBitOpenSearchWrite"
        Effect   = "Allow"
        Action   = ["es:ESHttp*"]
        Resource = ["arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch.domain_name}/*"]
      }
    ]
  })
}
