# ADR-0014: role OIDC de staging — assumida pelos jobs de build/push/smoke test
# de branches de desenvolvimento (develop, feature/*). Reusa o mesmo OIDC provider
# do ADR-0005 (aws_iam_openid_connect_provider.github). Nunca assumivel pelo job de
# promocao de producao (sub nao inclui environment:production).

data "aws_iam_policy_document" "github_staging_trust" {
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

resource "aws_iam_role" "github_staging" {
  name               = "devopsproject-github-staging-role"
  assume_role_policy = data.aws_iam_policy_document.github_staging_trust.json
}

data "aws_iam_policy_document" "github_staging" {
  statement {
    sid       = "ECRGetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push da tag sha-<git-sha> nos 6 repositorios — inclui upload de novas layers
  # (imagem construida a partir do zero em staging).
  statement {
    sid    = "ECRPushStagingImages"
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

  # Tunel SSM para o control plane (smoke test — kubectl wait via port forwarding).
  # Document AWS-managed (sem account id no ARN) + instancia restrita por tag
  # (Role=control-plane, ADR-0002/0014) — nunca os workers.
  statement {
    sid    = "SSMTunnelControlPlane"
    effect = "Allow"
    actions = [
      "ssm:StartSession",
    ]
    resources = [
      "arn:aws:ssm:${var.region}::document/AWS-StartPortForwardingSessionToRemoteHost",
      "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Role"
      values   = ["control-plane"]
    }
  }

  # NOTA (ADR-0014, guideline "Policy github-staging-role"): leitura de segredos
  # -stg via secretsmanager:GetSecretValue e listada como OPCIONAL — o proprio ADR
  # registra que o consumo de segredos pelos pods e via ESO/instance-role (ADR-0013),
  # nao pelo pipeline de CI. Nao concedida aqui; se um workflow futuro precisar ler
  # segredos -stg diretamente, adicionar statement dedicada + envs/staging.tfvars
  # com os ARNs -stg necessarios.
}

resource "aws_iam_role_policy" "github_staging" {
  name   = "devopsproject-github-staging-policy"
  role   = aws_iam_role.github_staging.id
  policy = data.aws_iam_policy_document.github_staging.json
}
