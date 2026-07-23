resource "aws_wafv2_web_acl" "this" {
  name  = "devopsproject-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  custom_response_body {
    key          = "suspicious-request"
    content      = "{\"error\":\"Access denied\",\"code\":403}"
    content_type = "APPLICATION_JSON"
  }

  rule {
    name     = "geo-non-br"
    priority = 1

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["BR"]
          }
        }
      }
    }

    action {
      count {}
    }

    rule_label {
      name = "devopsproject:suspicious:request"
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "geo-non-br"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-ip-reputation"
    priority = 10

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-anonymous-ip"
    priority = 20

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-anonymous-ip"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-sqli"
    priority = 30

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-bot-control"
    priority = 40

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-bot-control"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-common-rules"
    priority = 50

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      count {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "block-suspicious-by-label"
    priority = 100

    statement {
      label_match_statement {
        scope = "LABEL"
        key   = "devopsproject:suspicious:request"
      }
    }

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "suspicious-request"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block-suspicious-by-label"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "devopsproject-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "devopsproject-cloudfront-waf" }
}
