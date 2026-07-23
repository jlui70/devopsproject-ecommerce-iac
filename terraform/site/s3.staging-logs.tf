resource "aws_s3_bucket" "staging_logs" {
  bucket = var.site.staging_logs_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging_logs" {
  bucket = aws_s3_bucket.staging_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "staging_logs" {
  bucket = aws_s3_bucket.staging_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "staging_logs" {
  bucket = aws_s3_bucket.staging_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
