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

  # Leitura do manifesto/layers apos o push — necessaria para o cosign assinar a
  # imagem (cosign sign referencia a URL completa do ECR, nao a imagem local do
  # Docker, entao precisa falar direto com a API do registry). Achado ao vivo no
  # deploy do zero de 2026-08-12 (Fase 11.6): sem isso, "cosign sign" falha com
  # AccessDenied em ecr:BatchGetImage.
  statement {
    sid    = "ECRReadStagingImagesForSigning"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = local.ecr_repo_arns
  }

  # Descoberta do control-plane e do ALB interno de staging antes de abrir o tunel
  # SSM (smoke-test-staging). ec2:DescribeInstances e elbv2:DescribeLoadBalancers nao
  # suportam restricao por ARN de recurso no IAM (sempre Resource "*"), entao o
  # isolamento real fica por conta da condicao de tag no statement SSMTunnelControlPlane
  # abaixo — esta aqui so permite achar o instance-id/DNS, nao abrir sessao nenhuma.
  # Achado ao vivo no deploy do zero de 2026-08-12 (Fase 11.6).
  statement {
    sid    = "DescribeForSSMTunnelDiscovery"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "elasticloadbalancing:DescribeLoadBalancers",
    ]
    resources = ["*"]
  }

  # Tunel SSM para o control plane (smoke test — kubectl wait via port forwarding).
  #
  # CORRIGIDO (achado ao vivo no deploy do zero de 2026-08-12, via
  # iam simulate-principal-policy): documento e instancia precisam ser statements
  # SEPARADOS. Testado com o Policy Simulator: com os dois recursos no mesmo
  # statement + condition de tag, o documento avalia como implicitDeny (ele nao
  # carrega a tag ssm:resourceTag/Role, entao a condition nunca e satisfeita pra
  # esse recurso especifico, mesmo estando listado no Resource) — so a instancia
  # avaliava allowed isoladamente. O documento em si nao concede acesso a nenhuma
  # instancia sozinho (isso quem faz e o statement de baixo); nao ha problema em
  # deixa-lo sem condition.
  statement {
    sid    = "SSMPortForwardDocument"
    effect = "Allow"
    actions = [
      "ssm:StartSession",
    ]
    resources = [
      "arn:aws:ssm:${var.region}::document/AWS-StartPortForwardingSessionToRemoteHost",
    ]
  }

  # Instancia restrita por tag (Role=control-plane, ADR-0002/0014) — nunca os workers.
  statement {
    sid    = "SSMTunnelControlPlane"
    effect = "Allow"
    actions = [
      "ssm:StartSession",
    ]
    resources = [
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
