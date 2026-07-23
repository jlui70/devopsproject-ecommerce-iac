resource "aws_iam_role" "sns_feedback" {
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
  name = "devopsproject-sns-feedback-policy"
  role = aws_iam_role.sns_feedback.id

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
  name = var.sns.order_confirmed_topic_name

  sqs_success_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  sqs_failure_feedback_role_arn    = aws_iam_role.sns_feedback.arn
  sqs_success_feedback_sample_rate = 100

  tags = {
    Name = var.sns.order_confirmed_topic_name
  }
}
