resource "aws_s3_bucket" "app_files" {
  count = var.production_enabled ? 1 : 0

  bucket = var.app.s3_bucket

  tags = {
    Name = var.app.s3_bucket
  }
}

resource "aws_s3_bucket_versioning" "app_files" {
  count = var.production_enabled ? 1 : 0

  bucket = aws_s3_bucket.app_files[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_files" {
  count = var.production_enabled ? 1 : 0

  bucket = aws_s3_bucket.app_files[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_files" {
  count = var.production_enabled ? 1 : 0

  bucket = aws_s3_bucket.app_files[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
