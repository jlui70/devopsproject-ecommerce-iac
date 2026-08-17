region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

vpc = {
  name               = "devopsproject-vpc"
  cidr               = "10.0.0.0/24"
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs = {
    "us-east-1a" = "10.0.0.0/27"
    "us-east-1b" = "10.0.0.64/27"
  }
  private_subnet_cidrs = {
    "us-east-1a" = "10.0.0.32/27"
    "us-east-1b" = "10.0.0.96/27"
  }
}

route53 = {
  zone_name = "ecommerce-devopsproject.com"
}
