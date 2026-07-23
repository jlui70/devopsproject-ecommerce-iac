resource "aws_cloudwatch_log_group" "opensearch_audit" {
  name              = "/aws/opensearch/domains/${var.opensearch.domain_name}/audit-logs"
  retention_in_days = var.opensearch.audit_log_retention_days

  tags = {
    Name = "${var.opensearch.domain_name}-audit-logs"
  }
}

data "aws_iam_policy_document" "opensearch_audit_log" {
  statement {
    effect  = "Allow"
    actions = ["logs:PutLogEvents", "logs:CreateLogStream"]

    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }

    resources = ["${aws_cloudwatch_log_group.opensearch_audit.arn}:*"]
  }
}

resource "aws_cloudwatch_log_resource_policy" "opensearch_audit" {
  policy_name     = "devopsproject-opensearch-audit-log-policy"
  policy_document = data.aws_iam_policy_document.opensearch_audit_log.json
}
