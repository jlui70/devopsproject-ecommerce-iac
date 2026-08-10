resource "aws_sns_topic_subscription" "invoice" {
  count = var.production_enabled ? 1 : 0

  topic_arn            = aws_sns_topic.order_confirmed[0].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.invoice[0].arn
  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "product_stock" {
  count = var.production_enabled ? 1 : 0

  topic_arn            = aws_sns_topic.order_confirmed[0].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.product_stock[0].arn
  raw_message_delivery = false
}

resource "aws_sqs_queue_policy" "invoice_allow_sns" {
  count = var.production_enabled ? 1 : 0

  queue_url = aws_sqs_queue.invoice[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.invoice[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_confirmed[0].arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "product_stock_allow_sns" {
  count = var.production_enabled ? 1 : 0

  queue_url = aws_sqs_queue.product_stock[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.product_stock[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_confirmed[0].arn
          }
        }
      }
    ]
  })
}
