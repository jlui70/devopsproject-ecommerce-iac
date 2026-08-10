resource "aws_iam_role" "lambda" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_vpc_eni" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-vpc-eni-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCNetworkInterface"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-secrets-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerGetSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.aurora[0].arn,
          aws_secretsmanager_secret.docdb[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sqs" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-sqs-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSSendMessage"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.email_notification[0].arn,
          aws_sqs_queue.product_stock[0].arn,
          aws_sqs_queue.invoice[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sns" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-sns-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [aws_sns_topic.order_confirmed[0].arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_ca" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-s3-ca-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3GetDocumentDBCA"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.app.s3_bucket}/app/documentdb-ca.pem"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-lambda-logs-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
