provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }

  assume_role {
    role_arn    = var.assume_role.role_arn
    external_id = var.assume_role.external_id
  }
}

data "aws_caller_identity" "current" {}

provider "opensearch" {
  url               = "https://${aws_opensearch_domain.logs.endpoint}"
  username          = var.opensearch.master_user_name
  password          = var.opensearch_master_password
  healthcheck       = false
  sign_aws_requests = false
}
