output "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD was installed into."
  value       = helm_release.argocd.namespace
}

output "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart that was installed."
  value       = helm_release.argocd.version
}

output "eso_role_arn" {
  description = "ARN of the IAM role ESO assumes via IRSA to read from Secrets Manager."
  value       = aws_iam_role.eso.arn
}

output "eso_namespace" {
  description = "Kubernetes namespace ESO was installed into."
  value       = helm_release.eso.namespace
}
