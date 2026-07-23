data "aws_iam_policy_document" "control_plane_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "control_plane" {
  name               = "${var.cluster.name}-control-plane"
  assume_role_policy = data.aws_iam_policy_document.control_plane_assume_role.json

  tags = { Name = "${var.cluster.name}-control-plane" }
}

# Política gerenciada: SSM para acesso via Session Manager e Patch Manager
resource "aws_iam_role_policy_attachment" "control_plane_ssm" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política inline: Cloud Controller Manager (CCM) + ECR pull
data "aws_iam_policy_document" "control_plane_inline" {
  # Cloud Controller Manager — EC2 describe
  statement {
    sid    = "CCMDescribeEC2"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeAvailabilityZones",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
      "ec2:ModifyInstanceAttribute",
    ]
    resources = ["*"]
  }

  # Cloud Controller Manager — ELB classic
  statement {
    sid    = "CCMClassicELB"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
    ]
    resources = ["*"]
  }

  # Cloud Controller Manager — ELBv2
  statement {
    sid    = "CCMELBv2"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:AddTags",
    ]
    resources = ["*"]
  }

  # Cloud Controller Manager — Route53
  statement {
    sid    = "CCMRoute53"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
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

  # Ansible init-cluster — leitura do Terraform state no S3
  statement {
    sid    = "TerraformStateRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.ansible_ssm_bucket}",
      "arn:aws:s3:::${var.ansible_ssm_bucket}/*",
      "arn:aws:s3:::devopsproject-terraform-state-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::devopsproject-terraform-state-${data.aws_caller_identity.current.account_id}/*",
    ]
  }
}

resource "aws_iam_role_policy" "control_plane" {
  name   = "${var.cluster.name}-control-plane"
  role   = aws_iam_role.control_plane.id
  policy = data.aws_iam_policy_document.control_plane_inline.json
}

resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.cluster.name}-control-plane"
  role = aws_iam_role.control_plane.name

  tags = { Name = "${var.cluster.name}-control-plane" }
}
