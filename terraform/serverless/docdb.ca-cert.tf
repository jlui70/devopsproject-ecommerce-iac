resource "aws_s3_object" "documentdb_ca_cert" {
  count = var.production_enabled ? 1 : 0

  bucket = aws_s3_bucket.app_files[0].id
  key    = "app/documentdb-ca.pem"
  source = var.app.documentdb_ca_cert_path

  content_type = "application/x-pem-file"

  tags = {
    Name = "documentdb-ca-cert"
  }
}
