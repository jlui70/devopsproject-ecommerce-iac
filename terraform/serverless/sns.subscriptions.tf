resource "aws_sns_topic_subscription" "invoice" {
  topic_arn            = aws_sns_topic.order_confirmed.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.invoice.arn
  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "product_stock" {
  topic_arn            = aws_sns_topic.order_confirmed.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.product_stock.arn
  raw_message_delivery = false
}

resource "aws_sqs_queue_policy" "invoice_allow_sns" {
  queue_url = aws_sqs_queue.invoice.id

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
        Resource = aws_sqs_queue.invoice.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_confirmed.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "product_stock_allow_sns" {
  queue_url = aws_sqs_queue.product_stock.id

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
        Resource = aws_sqs_queue.product_stock.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_confirmed.arn
          }
        }
      }
    ]
  })
}
