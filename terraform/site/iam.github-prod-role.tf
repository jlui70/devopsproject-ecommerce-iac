# ADR-0014: role OIDC de producao — assumida SOMENTE pelo job de promocao vinculado
# ao GitHub Environment "production" (required reviewers). O claim OIDC "sub" so
# contem "environment:production" quando o job referencia esse Environment
# protegido — ou seja, a assuncao desta role exige ter passado pelo gate de
# aprovacao manual (fail-safe: sem o Environment, a assuncao falha).
#
# Permissoes deliberadamente NAO incluem InitiateLayerUpload/UploadLayerPart/
# CompleteLayerUpload — a promocao e sempre um re-tag da digest ja existente
# (sha-<git-sha> -> release-YYYYMMDD-<sha-curta>), nunca um rebuild (ADR-0011/0013).

data "aws_iam_policy_document" "github_prod_trust" {
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
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github.repo}:environment:production"]
    }
  }
}

resource "aws_iam_role" "github_prod" {
  name               = "devopsproject-github-prod-role"
  assume_role_policy = data.aws_iam_policy_document.github_prod_trust.json
}

data "aws_iam_policy_document" "github_prod" {
  statement {
    sid       = "ECRGetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Re-tag da digest existente: le o manifest (BatchGetImage) e registra a nova
  # tag release-* apontando para a mesma digest (PutImage). Sem upload de layers.
  statement {
    sid    = "ECRPromoteImages"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:PutImage",
    ]
    resources = local.ecr_repo_arns
  }
}

resource "aws_iam_role_policy" "github_prod" {
  name   = "devopsproject-github-prod-policy"
  role   = aws_iam_role.github_prod.id
  policy = data.aws_iam_policy_document.github_prod.json
}
