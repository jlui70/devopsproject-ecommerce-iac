# ADR-0007 — Additional worker ASG for t3.small instance type
# Purpose: Enables the cluster-autoscaler priority-expander to prefer t3.small nodes
# (better value for .NET consumer workloads) over the existing t3.micro ASG.
# Tags mirror ec2.instances.worker.tf — both are discovered by the CA auto-discovery tag query.
# Ref: ADR-0007 Decision 2 / Option E (turbinar cluster-autoscaler).
#
# IMPORTANT: This ASG starts with min=0/desired=0 — nodes are provisioned on-demand by CA.
# The existing t3.micro ASG (ec2.instances.worker.tf) retains desired=4 as the baseline.

module "ec2_workers_t3_small_instances" {
  source                = "./modules/ec2"
  instance_profile_name = aws_iam_instance_profile.instance_profile.name
  launch_template = {
    name                                 = var.worker_t3_small_launch_template.name
    disable_api_stop                     = var.worker_t3_small_launch_template.disable_api_stop
    disable_api_termination              = var.worker_t3_small_launch_template.disable_api_termination
    instance_type                        = var.worker_t3_small_launch_template.instance_type
    instance_initiated_shutdown_behavior = var.worker_t3_small_launch_template.instance_initiated_shutdown_behavior
    key_name                             = aws_key_pair.this.key_name
    image_id                             = data.aws_ami.this.image_id
    vpc_security_group_ids               = [aws_security_group.worker.id]
    user_data                            = filebase64(var.worker_t3_small_launch_template.user_data)
    ebs = {
      size                  = var.worker_t3_small_launch_template.ebs.size
      delete_on_termination = var.worker_t3_small_launch_template.ebs.delete_on_termination
    }
  }
  auto_scaling_group = {
    name                      = var.worker_t3_small_auto_scaling_group.name
    max_size                  = var.worker_t3_small_auto_scaling_group.max_size
    min_size                  = var.worker_t3_small_auto_scaling_group.min_size
    desired_capacity          = var.worker_t3_small_auto_scaling_group.desired_capacity
    health_check_grace_period = var.worker_t3_small_auto_scaling_group.health_check_grace_period
    health_check_type         = var.worker_t3_small_auto_scaling_group.health_check_type
    vpc_zone_identifier       = data.aws_subnets.private_subnets.ids
    target_group_arns         = []
    instance_tags = merge(
      { PatchGroup = var.patch_group },
      {
        "k8s.io/cluster-autoscaler/enabled"                 = true,
        "k8s.io/cluster-autoscaler/devops-na-nuvem-cluster" = "owned",
        "aws-node-termination-handler/managed"              = true,
        "kubernetes.io/cluster/devops-na-nuvem-cluster"     = "owned"
      },
      var.tags,
      var.worker_t3_small_auto_scaling_group.instance_tags
    )
    instance_maintenance_policy = {
      min_healthy_percentage = var.worker_t3_small_auto_scaling_group.instance_maintenance_policy.min_healthy_percentage
      max_healthy_percentage = var.worker_t3_small_auto_scaling_group.instance_maintenance_policy.max_healthy_percentage
    }
  }
  tags = var.tags
}
