# --- DLQs (criadas antes das filas de origem para o redrive_policy) ---

resource "aws_sqs_queue" "email_notification_dlq" {
  name                      = var.sqs.email_notification_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name = var.sqs.email_notification_dlq_name
  }
}

resource "aws_sqs_queue" "product_stock_dlq" {
  name                      = var.sqs.product_stock_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name = var.sqs.product_stock_dlq_name
  }
}

resource "aws_sqs_queue" "invoice_dlq" {
  name                      = var.sqs.invoice_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name = var.sqs.invoice_dlq_name
  }
}

# --- Filas de producao ---

resource "aws_sqs_queue" "email_notification" {
  name                      = var.sqs.email_notification_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_notification_dlq.arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.email_notification_queue_name
  }
}

resource "aws_sqs_queue" "product_stock" {
  name                      = var.sqs.product_stock_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_stock_dlq.arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.product_stock_queue_name
  }
}

resource "aws_sqs_queue" "invoice" {
  name                      = var.sqs.invoice_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.invoice_dlq.arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.invoice_queue_name
  }
}

# --- Redrive allow policies nas DLQs (byQueue apontando para a fila de origem) ---

resource "aws_sqs_queue_redrive_allow_policy" "email_notification_dlq" {
  queue_url = aws_sqs_queue.email_notification_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.email_notification.arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "product_stock_dlq" {
  queue_url = aws_sqs_queue.product_stock_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.product_stock.arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "invoice_dlq" {
  queue_url = aws_sqs_queue.invoice_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.invoice.arn]
  })
}
