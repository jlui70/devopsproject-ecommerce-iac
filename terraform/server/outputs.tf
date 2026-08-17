output "nlb_dns_name" {
  description = "DNS do NLB interno — usado como controlPlaneEndpoint no kubeadm"
  value       = aws_lb.apiserver.dns_name
}

output "acm_certificate_arn" {
  description = "ARN do certificado ACM — consumido por PRD-004 (Ingress) e PRD-006 (CloudFront)"
  value       = aws_acm_certificate.this.arn
}

output "control_plane_security_group_id" {
  description = "ID do SG do control plane — consumido por PRD-003 (ingress dos bancos)"
  value       = aws_security_group.control_plane.id
}

output "worker_security_group_id" {
  description = "ID do SG dos workers — consumido por PRD-003 (ingress dos bancos)"
  value       = aws_security_group.worker.id
}

output "ecr_repository_urls" {
  description = "URLs dos repositórios ECR — consumidos por PRD-005 (push) e PRD-004 (deploy)"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "ec2_key_pair_private_key" {
  description = "Chave privada RSA — acesso de emergência aos nodes"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

output "node_termination_queue_url" {
  description = "URL da fila SQS do Node Termination Handler"
  value       = aws_sqs_queue.node_termination.url
}

output "worker_instance_role_arn" {
  description = "ARN da IAM role dos worker nodes — consumido por ADR-0007 (observability) para anexar policy do OpenSearch"
  value       = aws_iam_role.worker.arn
}

output "control_plane_instance_role_arn" {
  description = "ARN da IAM role dos control plane nodes — consumido por ADR-0007 (observability), role mapping do OpenSearch (Fluent Bit roda como DaemonSet em todos os nodes, inclusive control plane)"
  value       = aws_iam_role.control_plane.arn
}
