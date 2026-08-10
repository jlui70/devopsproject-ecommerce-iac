resource "aws_iam_role" "sns_feedback" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-sns-feedback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sns_feedback" {
  count = var.production_enabled ? 1 : 0

  name = "devopsproject-sns-feedback-policy"
  role = aws_iam_role.sns_feedback[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutMetricFilter",
          "logs:PutRetentionPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "order_confirmed" {
  count = var.production_enabled ? 1 : 0

  name = var.sns.order_confirmed_topic_name

  tags = {
    Name = var.sns.order_confirmed_topic_name
  }
}
