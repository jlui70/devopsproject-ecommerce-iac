data "aws_iam_policy_document" "worker_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  name               = "${var.cluster.name}-worker"
  assume_role_policy = data.aws_iam_policy_document.worker_assume_role.json

  tags = { Name = "${var.cluster.name}-worker" }
}

# Política gerenciada: SSM para acesso via Session Manager e Patch Manager
resource "aws_iam_role_policy_attachment" "worker_ssm" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política inline: Cluster Autoscaler + External DNS + ALB Controller + NTH + ECR pull
data "aws_iam_policy_document" "worker_inline" {
  # Cluster Autoscaler
  statement {
    sid    = "ClusterAutoscaler"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchTemplateVersions",
      "autoscaling:DescribeTags",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
  }

  # External DNS
  statement {
    sid    = "ExternalDNS"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }

  # AWS Load Balancer Controller — EC2 describe
  statement {
    sid    = "ALBControllerEC2"
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["*"]
  }

  # AWS Load Balancer Controller — ELBv2
  statement {
    sid    = "ALBControllerELBv2"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

  # Node Termination Handler — SQS
  statement {
    sid    = "NTHSQSAccess"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
    ]
    resources = [aws_sqs_queue.node_termination.arn]
  }

  # ECR pull
  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }

  # External Secrets Operator — Secrets Manager read (producao + staging).
  # Mecanismo de autenticacao do ESO num cluster kubeadm sem IRSA/EKS Pod Identity
  # (ADR-0013): os pods leem segredos via ESO usando a instance-role do worker.
  #
  # Confirmado contra terraform/serverless/secrets.*.tf (ADR-0012 implementado):
  # tanto os segredos de producao (devopsproject/app/secrets,
  # devopsproject/docdb/master-user-secret) quanto os de staging
  # (devopsproject/app/secrets-stg, devopsproject/docdb-stg/master-user-secret)
  # vivem sob o mesmo namespace "devopsproject/*" — um unico padrao de prefixo
  # cobre os dois ambientes. O segredo gerenciado do Aurora (producao e staging,
  # via manage_master_user_password) tem ARN gerado pela AWS fora desse namespace
  # ("rds!cluster-..."), mas nao precisa ser lido pelo ESO em runtime: o valor ja
  # e' incorporado ao secret agregado "devopsproject/app/secrets[-stg]" em tempo
  # de apply do Terraform (data source lido com a role de deploy, nao pela
  # instance-role do worker).
  statement {
    sid    = "ESOSecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:us-east-1:692430448478:secret:devopsproject/*",
    ]
  }

  # Order service — Lambda invocation (order-confirmed gateway)
  statement {
    sid    = "LambdaInvokeOrderConfirmed"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      "arn:aws:lambda:us-east-1:692430448478:function:orderConfirmedLambdaFunction",
    ]
  }

  # Application SQS — Main (ProductStockQueue), InvoiceGenerator, Notificator.
  # Inclui as filas -stg (ADR-0012): os pods do namespace staging rodam nos
  # mesmos workers de producao (mesma instance-role, sem IRSA), entao o KEDA
  # ScaledObject e os workers .NET de staging precisam do mesmo acesso as suas
  # proprias filas.
  statement {
    sid    = "AppSQSAccess"
    effect = "Allow"
    actions = [
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:SendMessage",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [
      "arn:aws:sqs:us-east-1:692430448478:ProductStockQueue",
      "arn:aws:sqs:us-east-1:692430448478:EmailNotificationQueue",
      "arn:aws:sqs:us-east-1:692430448478:InvoiceQueue",
      "arn:aws:sqs:us-east-1:692430448478:ProductStockQueueDlq",
      "arn:aws:sqs:us-east-1:692430448478:EmailNotificationQueueDlq",
      "arn:aws:sqs:us-east-1:692430448478:InvoiceQueueDlq",
      "arn:aws:sqs:us-east-1:692430448478:ProductStockQueue-stg",
      "arn:aws:sqs:us-east-1:692430448478:EmailNotificationQueue-stg",
      "arn:aws:sqs:us-east-1:692430448478:InvoiceQueue-stg",
      "arn:aws:sqs:us-east-1:692430448478:ProductStockQueueDlq-stg",
      "arn:aws:sqs:us-east-1:692430448478:EmailNotificationQueueDlq-stg",
      "arn:aws:sqs:us-east-1:692430448478:InvoiceQueueDlq-stg",
    ]
  }

  # Notificator — SES send (order-confirmed email)
  statement {
    sid    = "SESSendEmail"
    effect = "Allow"
    actions = [
      "ses:SendTemplatedEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "${var.cluster.name}-worker"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_inline.json
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster.name}-worker"
  role = aws_iam_role.worker.name

  tags = { Name = "${var.cluster.name}-worker" }
}
