# Emenda ADR-0011 (2026-08-10): distribuicao CloudFront dedicada e exclusiva para os
# arquivos estaticos do frontend do ambiente de aplicacao `staging`. Serve em
# app-staging.ecommerce-devopsproject.com — subdominio distinto de
# staging.ecommerce-devopsproject.com (ADR-0014), que continua sendo exclusivamente o
# backend/API interno via ALB e NAO e alterado por este arquivo.
#
# Escopo estrito da emenda: origem unica S3 (via OAC), sem VPC Origin, sem roteamento
# para o ALB e sem WAF (web_acl_id) — e conteudo publico estatico, sem dados sensiveis.
# Nao confundir com aws_cloudfront_distribution.staging (cloudfront.staging.tf), que e o
# CloudFront Continuous Deployment (canario de config de CDN, ADR-0006/0011).

resource "aws_cloudfront_distribution" "frontend_staging" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = "index.html"
  price_class         = "PriceClass_All"
  aliases             = [var.site.frontend_staging_domain]

  origin {
    origin_id                = "s3-frontend-staging"
    domain_name              = aws_s3_bucket.frontend_staging.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend-staging"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend_staging.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = aws_s3_bucket.site_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront-frontend-staging/"
  }

  # SPA routing: redireciona 403/404 do S3 para index.html (React Router cuida das rotas) —
  # mesmo comportamento da distribuicao de producao (cloudfront.production.tf).
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
}
