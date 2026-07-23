output "asg_name" {
  description = "Nome do Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN do Auto Scaling Group"
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "ID do Launch Template"
  value       = aws_launch_template.this.id
}
