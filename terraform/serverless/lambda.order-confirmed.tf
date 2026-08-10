data "archive_file" "order_confirmed" {
  type        = "zip"
  source_dir  = var.lambda.order_confirmed_source_path
  output_path = "${path.module}/.build/order-confirmed.zip"
}

resource "aws_lambda_function" "order_confirmed" {
  count = var.production_enabled ? 1 : 0

  function_name    = var.lambda.order_confirmed_function_name
  filename         = data.archive_file.order_confirmed.output_path
  source_code_hash = data.archive_file.order_confirmed.output_base64sha256
  role             = aws_iam_role.lambda[0].arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  layers           = [aws_lambda_layer_version.this[0].arn]

  vpc_config {
    subnet_ids         = local.private_subnets_ids
    security_group_ids = [aws_security_group.lambda[0].id, aws_security_group.postgresql[0].id]
  }

  environment {
    variables = {
      RDS_PROXY_ENDPOINT = aws_db_proxy.postgresql[0].endpoint
      SECRET_ARN         = aws_secretsmanager_secret.aurora[0].arn
      SNS_TOPIC_ARN      = aws_sns_topic.order_confirmed[0].arn
      SQS_EMAIL_URL      = aws_sqs_queue.email_notification[0].url
      REGION             = var.region
    }
  }

  tags = {
    Name = var.lambda.order_confirmed_function_name
  }
}

resource "aws_lambda_function_url" "order_confirmed" {
  count = var.production_enabled ? 1 : 0

  function_name      = aws_lambda_function.order_confirmed[0].function_name
  authorization_type = "AWS_IAM"
}
