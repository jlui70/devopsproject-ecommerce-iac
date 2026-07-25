resource "aws_s3_bucket" "site_logs" {
  bucket        = var.site.logs_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site_logs" {
  bucket = aws_s3_bucket.site_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "site_logs" {
  bucket = aws_s3_bucket.site_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site_logs" {
  bucket = aws_s3_bucket.site_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
