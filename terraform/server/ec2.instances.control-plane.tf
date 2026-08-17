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
    # ADR-0022 e' so' para workers (auto-join no boot) — control plane nunca deve
    # rodar kubeadm join, so' kubeadm init (feito pelo Ansible, roles/init-cluster).
    extra_user_data = ""
    maintenance_policy = {
      min_healthy_percentage = 100
      max_healthy_percentage = 110
    }
    extra_tags = {
      "PatchGroup"                                = "Production"
      "kubernetes.io/cluster/${var.cluster.name}" = "owned"
      # ADR-0014: distingue as instancias de control-plane das de worker para o
      # condition ssm:resourceTag/Role da policy de tunel SSM (github-staging-role,
      # stack site/) — sem esta tag, nao ha como restringir ssm:StartSession
      # somente ao control plane (PatchGroup/kubernetes.io/cluster sao compartilhados
      # com os workers).
      "Role" = "control-plane"
    }
  }
}
