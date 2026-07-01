output "alb_security_group_id" {
  description = "Security group ID of the ALB. Used in the ALB Ingress annotation so LBC uses this SG instead of creating a new one."
  value       = aws_security_group.alb.id
}

output "lbc_role_arn" {
  description = "ARN of the IAM role the AWS LBC pod assumes via IRSA."
  value       = aws_iam_role.lbc.arn
}

output "nginx_namespace" {
  description = "Kubernetes namespace NGINX Ingress Controller is installed in."
  value       = helm_release.nginx.namespace
}

output "lbc_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart that was installed."
  value       = helm_release.lbc.version
}

output "nginx_chart_version" {
  description = "Version of the ingress-nginx Helm chart that was installed."
  value       = helm_release.nginx.version
}
