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

output "ebs_csi_role_arn" {
  description = "ARN of the IAM role the EBS CSI driver pod assumes via IRSA. Null when enable_ebs_csi_driver is false."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}
