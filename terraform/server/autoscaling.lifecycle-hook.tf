resource "aws_autoscaling_lifecycle_hook" "worker_termination" {
  name                   = "node-termination-handler"
  autoscaling_group_name = module.worker.asg_name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 300
  default_result         = "CONTINUE"
}
