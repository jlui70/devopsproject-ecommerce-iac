resource "aws_iam_role" "scheduler" {
  name = "devopsproject-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "devopsproject-scheduler-invoke-lambda-policy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.report_job.arn]
      }
    ]
  })
}

resource "aws_scheduler_schedule" "report_job" {
  name       = "devopsproject-report-job-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.lambda.scheduler_expression

  target {
    arn      = aws_lambda_function.report_job.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
