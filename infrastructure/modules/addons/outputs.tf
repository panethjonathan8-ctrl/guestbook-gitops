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
