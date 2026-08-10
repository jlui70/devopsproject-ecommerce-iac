# --- DLQs (criadas antes das filas de origem para o redrive_policy) ---

resource "aws_sqs_queue" "email_notification_dlq" {
  count = var.production_enabled ? 1 : 0

  name                      = var.sqs.email_notification_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name = var.sqs.email_notification_dlq_name
  }
}

resource "aws_sqs_queue" "product_stock_dlq" {
  count = var.production_enabled ? 1 : 0

  name                      = var.sqs.product_stock_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name = var.sqs.product_stock_dlq_name
  }
}

resource "aws_sqs_queue" "invoice_dlq" {
  count = var.production_enabled ? 1 : 0

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
  count = var.production_enabled ? 1 : 0

  name                      = var.sqs.email_notification_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_notification_dlq[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.email_notification_queue_name
  }
}

resource "aws_sqs_queue" "product_stock" {
  count = var.production_enabled ? 1 : 0

  name                      = var.sqs.product_stock_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_stock_dlq[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.product_stock_queue_name
  }
}

resource "aws_sqs_queue" "invoice" {
  count = var.production_enabled ? 1 : 0

  name                      = var.sqs.invoice_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.invoice_dlq[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name = var.sqs.invoice_queue_name
  }
}

# --- Redrive allow policies nas DLQs (byQueue apontando para a fila de origem) ---

resource "aws_sqs_queue_redrive_allow_policy" "email_notification_dlq" {
  count = var.production_enabled ? 1 : 0

  queue_url = aws_sqs_queue.email_notification_dlq[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.email_notification[0].arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "product_stock_dlq" {
  count = var.production_enabled ? 1 : 0

  queue_url = aws_sqs_queue.product_stock_dlq[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.product_stock[0].arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "invoice_dlq" {
  count = var.production_enabled ? 1 : 0

  queue_url = aws_sqs_queue.invoice_dlq[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.invoice[0].arn]
  })
}

# --- ADR-0012: filas + DLQs do ambiente staging (sufixo -stg) ---
# Mesmos parametros de retention/visibility/redrive/SSE da producao acima —
# paridade de comportamento e requisito explicito do ADR (Decisao central).

# DLQs staging (criadas antes das filas de origem para o redrive_policy)

resource "aws_sqs_queue" "email_notification_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.email_notification_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = var.staging.sqs.email_notification_dlq_name
    Environment = "staging"
  }
}

resource "aws_sqs_queue" "product_stock_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.product_stock_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = var.staging.sqs.product_stock_dlq_name
    Environment = "staging"
  }
}

resource "aws_sqs_queue" "invoice_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.invoice_dlq_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = var.staging.sqs.invoice_dlq_name
    Environment = "staging"
  }
}

# Filas de staging

resource "aws_sqs_queue" "email_notification_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.email_notification_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_notification_dlq_staging[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name        = var.staging.sqs.email_notification_queue_name
    Environment = "staging"
  }
}

resource "aws_sqs_queue" "product_stock_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.product_stock_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_stock_dlq_staging[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name        = var.staging.sqs.product_stock_queue_name
    Environment = "staging"
  }
}

resource "aws_sqs_queue" "invoice_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  name                      = var.staging.sqs.invoice_queue_name
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  sqs_managed_sse_enabled   = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.invoice_dlq_staging[0].arn
    maxReceiveCount     = 2
  })

  tags = {
    Name        = var.staging.sqs.invoice_queue_name
    Environment = "staging"
  }
}

# Redrive allow policies nas DLQs staging (byQueue apontando para a fila -stg de origem)

resource "aws_sqs_queue_redrive_allow_policy" "email_notification_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  queue_url = aws_sqs_queue.email_notification_dlq_staging[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.email_notification_staging[0].arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "product_stock_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  queue_url = aws_sqs_queue.product_stock_dlq_staging[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.product_stock_staging[0].arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "invoice_dlq_staging" {
  count = var.staging != null && var.staging.enabled ? 1 : 0

  queue_url = aws_sqs_queue.invoice_dlq_staging[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.invoice_staging[0].arn]
  })
}
