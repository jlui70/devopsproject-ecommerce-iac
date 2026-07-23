module "worker" {
  source = "./modules/ec2"

  config = {
    name                        = "${var.cluster.name}-worker"
    ami_id                      = data.aws_ami.debian.id
    instance_type               = var.worker.instance_type
    ebs_size_gb                 = var.worker.ebs_size_gb
    instance_profile_name       = aws_iam_instance_profile.worker.name
    security_group_ids          = [aws_security_group.worker.id]
    subnet_ids                  = data.terraform_remote_state.networking.outputs.private_subnets_ids
    key_name                    = aws_key_pair.this.key_name
    http_put_response_hop_limit = 2
    asg                         = var.worker.asg
    target_group_arns           = []
    suspended_processes         = ["AZRebalance"]
    maintenance_policy = {
      min_healthy_percentage = 100
      max_healthy_percentage = 110
    }
    extra_tags = {
      "PatchGroup"                                    = "Production"
      "kubernetes.io/cluster/${var.cluster.name}"     = "owned"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster.name}" = "owned"
      "aws-node-termination-handler/managed"          = "true"
    }
  }
}
