module "control_plane" {
  source = "./modules/ec2"

  config = {
    name                        = "${var.cluster.name}-control-plane"
    ami_id                      = data.aws_ami.debian.id
    instance_type               = var.control_plane.instance_type
    ebs_size_gb                 = var.control_plane.ebs_size_gb
    instance_profile_name       = aws_iam_instance_profile.control_plane.name
    security_group_ids          = [aws_security_group.control_plane.id]
    subnet_ids                  = data.terraform_remote_state.networking.outputs.private_subnets_ids
    key_name                    = aws_key_pair.this.key_name
    http_put_response_hop_limit = 2
    asg                         = var.control_plane.asg
    target_group_arns           = [aws_lb_target_group.apiserver.arn]
    suspended_processes         = ["AZRebalance"]
    maintenance_policy = {
      min_healthy_percentage = 100
      max_healthy_percentage = 110
    }
    extra_tags = {
      "PatchGroup"                                = "Production"
      "kubernetes.io/cluster/${var.cluster.name}" = "owned"
    }
  }
}
