# Emenda ADR-0011 (2026-08-10): role OIDC dedicada e escopada para o deploy do frontend
# estatico do ambiente de aplicacao `staging` — mesmo padrao de trust (ref develop/feature/*)
# da aws_iam_role.github_staging (iam.github-staging-role.tf, ADR-0014), reusando o mesmo
# OIDC provider do ADR-0005 (aws_iam_openid_connect_provider.github). Escopo estrito: somente
# o bucket e a distribuicao CloudFront novos deste arquivo — nenhuma permissao sobre os
# recursos de producao (aws_s3_bucket.site / aws_cloudfront_distribution.production).

data "aws_iam_policy_document" "github_frontend_staging_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github.repo}:ref:refs/heads/develop",
        "repo:${var.github.repo}:ref:refs/heads/feature/*",
      ]
    }
  }
}

resource "aws_iam_role" "github_frontend_staging" {
  name               = "devopsproject-github-frontend-staging-role"
  assume_role_policy = data.aws_iam_policy_document.github_frontend_staging_trust.json
}

data "aws_iam_policy_document" "github_frontend_staging" {
  statement {
    sid    = "S3Objects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.frontend_staging.arn}/*"]
  }

  statement {
    sid       = "S3ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.frontend_staging.arn]
  }

  statement {
    sid       = "CloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.frontend_staging.arn]
  }
}

resource "aws_iam_role_policy" "github_frontend_staging" {
  name   = "devopsproject-github-frontend-staging-policy"
  role   = aws_iam_role.github_frontend_staging.id
  policy = data.aws_iam_policy_document.github_frontend_staging.json
}
