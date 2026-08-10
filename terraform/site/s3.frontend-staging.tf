# Emenda ADR-0011 (2026-08-10): bucket S3 privado para os arquivos estaticos do build
# (Vite/React) do frontend do ambiente de aplicacao `staging`. Acesso somente via OAC do
# CloudFront (aws_cloudfront_distribution.frontend_staging, cloudfront.frontend-staging.tf).
# Nao confundir com aws_s3_bucket.staging (s3.staging.tf) — aquele bucket serve a *staging
# distribution* do CloudFront Continuous Deployment (canario de config de CDN, ADR-0006/0011),
# um recurso completamente diferente.

resource "aws_s3_bucket" "frontend_staging" {
  bucket        = var.site.frontend_staging_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "frontend_staging" {
  bucket = aws_s3_bucket.frontend_staging.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_staging" {
  bucket = aws_s3_bucket.frontend_staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_staging" {
  bucket = aws_s3_bucket.frontend_staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "frontend_staging" {
  bucket        = aws_s3_bucket.frontend_staging.id
  target_bucket = aws_s3_bucket.site_logs.id
  target_prefix = "s3-frontend-staging/"
}

data "aws_iam_policy_document" "frontend_staging_bucket" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_staging.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend_staging.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_staging" {
  bucket = aws_s3_bucket.frontend_staging.id
  policy = data.aws_iam_policy_document.frontend_staging_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.frontend_staging]
}
