output "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD was installed into."
  value       = helm_release.argocd.namespace
}

output "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart that was installed."
  value       = helm_release.argocd.version
}
