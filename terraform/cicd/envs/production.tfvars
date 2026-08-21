region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

github = {
  repo            = "jlui70/devopsproject-ecommerce"
  oidc_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
}
