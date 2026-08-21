data "aws_iam_policy_document" "github_frontend_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github.repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_frontend" {
  name               = "devopsproject-github-frontend-role"
  assume_role_policy = data.aws_iam_policy_document.github_frontend_trust.json
}

data "aws_iam_policy_document" "github_frontend" {
  statement {
    sid    = "S3Objects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.site.arn}/*",
      "${aws_s3_bucket.staging.arn}/*",
    ]
  }

  statement {
    sid     = "S3ListBuckets"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.site.arn,
      aws_s3_bucket.staging.arn,
    ]
  }

  statement {
    sid     = "CloudFrontInvalidation"
    effect  = "Allow"
    actions = ["cloudfront:CreateInvalidation"]
    resources = [
      aws_cloudfront_distribution.production.arn,
      aws_cloudfront_distribution.staging.arn,
    ]
  }

  # ADR-0023: o workflow resolve o distribution ID pelo alias em runtime, em vez de
  # receber o ID num secret preenchido a mao. ListDistributions nao aceita restricao
  # por ARN de recurso no IAM (sempre Resource "*") — o escopo real continua sendo o
  # CreateInvalidation acima, restrito as distribuicoes desta stack.
  statement {
    sid       = "CloudFrontListForAliasLookup"
    effect    = "Allow"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_frontend" {
  name   = "devopsproject-github-frontend-policy"
  role   = aws_iam_role.github_frontend.id
  policy = data.aws_iam_policy_document.github_frontend.json
}
