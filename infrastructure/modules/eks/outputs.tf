output "cluster_endpoint" {
  description = "HTTPS endpoint of the EKS cluster API server. Consumed by addons and argocd for the Kubernetes/Helm providers."
  value       = module.this.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data. Consumed by addons and argocd for the Kubernetes/Helm providers."
  value       = module.this.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider. Consumed by addons and argocd to build IRSA trust policies."
  value       = module.this.oidc_provider_arn
}

output "cluster_version" {
  description = "Running Kubernetes control plane version. Consumed by prod addons to pin kubectl-compatible addon versions."
  value       = module.this.cluster_version
}

output "node_security_group_id" {
  description = "Security group ID shared by all managed node group instances. Consumed by rds to allow inbound Postgres only from cluster nodes."
  value       = module.this.node_security_group_id
}
