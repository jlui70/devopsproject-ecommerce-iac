resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "devopsproject-site-oac"
  description                       = "OAC SigV4 para bucket S3 do site devopsproject"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
