# ADR-0005 (origem) / ADR-0023 (movido de `site` para `cicd`).
#
# DEPRECADA — nenhum workflow em devopsproject-ecommerce/.github/workflows/ assume
# esta role. O push de imagens em CI e' feito por aws_iam_role.github_staging
# (ADR-0014) e a promocao por aws_iam_role.github_prod. Mantida por ora para nao
# misturar remocao de recurso com o resequenciamento do ADR-0023; candidata a
# remocao num ADR proprio.

data "aws_iam_policy_document" "github_backend_trust" {
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
      values   = ["repo:${var.github.repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_backend" {
  name               = "devopsproject-github-backend-role"
  assume_role_policy = data.aws_iam_policy_document.github_backend_trust.json
}

data "aws_iam_policy_document" "github_backend" {
  statement {
    sid       = "ECRGetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = local.ecr_repo_arns
  }
}

resource "aws_iam_role_policy" "github_backend" {
  name   = "devopsproject-github-backend-policy"
  role   = aws_iam_role.github_backend.id
  policy = data.aws_iam_policy_document.github_backend.json
}
