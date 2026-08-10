data "archive_file" "report_job" {
  type        = "zip"
  source_dir  = var.lambda.report_job_source_path
  output_path = "${path.module}/.build/report-job.zip"
}

resource "aws_lambda_function" "report_job" {
  count = var.production_enabled ? 1 : 0

  function_name    = var.lambda.report_job_function_name
  filename         = data.archive_file.report_job.output_path
  source_code_hash = data.archive_file.report_job.output_base64sha256
  role             = aws_iam_role.lambda[0].arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 30
  layers           = [aws_lambda_layer_version.this[0].arn]

  vpc_config {
    subnet_ids         = local.private_subnets_ids
    security_group_ids = [aws_security_group.lambda[0].id, aws_security_group.postgresql[0].id, aws_security_group.documentdb[0].id]
  }

  environment {
    variables = {
      RDS_PROXY_READONLY_ENDPOINT = aws_db_proxy_endpoint.readonly[0].endpoint
      DOCDB_ENDPOINT              = aws_docdb_cluster.this[0].endpoint
      DOCDB_SECRET_ARN            = aws_secretsmanager_secret.docdb[0].arn
      DOCUMENTDB_CERT_OBJECT_KEY  = "app/documentdb-ca.pem"
      S3_BUCKET                   = var.app.s3_bucket
      REGION                      = var.region
    }
  }

  tags = {
    Name = var.lambda.report_job_function_name
  }
}
