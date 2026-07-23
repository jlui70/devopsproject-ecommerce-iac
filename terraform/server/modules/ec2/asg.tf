resource "aws_autoscaling_group" "this" {
  name                = var.config.name
  min_size            = var.config.asg.min
  desired_capacity    = var.config.asg.desired
  max_size            = var.config.asg.max
  vpc_zone_identifier = var.config.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 180

  target_group_arns   = var.config.target_group_arns
  suspended_processes = var.config.suspended_processes

  instance_maintenance_policy {
    min_healthy_percentage = var.config.maintenance_policy.min_healthy_percentage
    max_healthy_percentage = var.config.maintenance_policy.max_healthy_percentage
  }

  dynamic "tag" {
    for_each = var.config.extra_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
