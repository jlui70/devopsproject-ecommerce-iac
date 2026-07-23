data "aws_iam_policy_document" "opensearch" {
  statement {
    effect  = "Allow"
    actions = ["es:ESHttp*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch.domain_name}/*"]
  }
}
