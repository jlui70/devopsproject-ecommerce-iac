region = "us-east-1"

assume_role = {
  role_arn    = "arn:aws:iam::692430448478:role/terraform-role"
  external_id = "f5deb027-47e2-4079-bdaf-26c0beac6216"
}

state_backend = {
  bucket_name = "devopsproject-terraform-state-692430448478"
  table_name  = "devopsproject-terraform-state-locking"
}
