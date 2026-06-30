variable "cluster_name" {
  description = "Name of the EKS cluster ArgoCD will be installed into."
  type        = string
}

variable "cluster_endpoint" {
  description = "HTTPS endpoint of the EKS cluster API server."
  type        = string
}

variable "cluster_ca" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  type        = string
}

variable "region" {
  description = "AWS region the EKS cluster lives in."
  type        = string
}

variable "env_name" {
  description = "Environment name (dev, prod) — selects the correct App-of-Apps values file."
  type        = string
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the GitOps repository ArgoCD will sync from."
  type        = string
}

variable "gitops_repo_branch" {
  description = "Git branch ArgoCD will track."
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart to install."
  type        = string
  default     = "7.9.0"
}

variable "argocd_apps_chart_version" {
  description = "Version of the argocd-apps Helm chart used to create the bootstrap Application."
  type        = string
  default     = "2.0.2"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD will be installed into."
  type        = string
  default     = "argocd"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider. Used in the ESO IRSA trust policy so ESO pods can assume the IAM role without static credentials."
  type        = string
}

variable "account_id" {
  description = "AWS account ID. Used to scope the Secrets Manager IAM policy to this account."
  type        = string
}

variable "eso_chart_version" {
  description = "Version of the external-secrets Helm chart to install."
  type        = string
  default     = "0.10.3"
}

variable "eso_namespace" {
  description = "Kubernetes namespace ESO will be installed into."
  type        = string
  default     = "external-secrets"
}

variable "eso_secret_name_prefixes" {
  description = "Secrets Manager secret name prefixes ESO is allowed to read. Defaults to [\"guestbook/{env_name}\"] when empty. Override when a cluster serves multiple environments — e.g. [\"guestbook/dev\", \"guestbook/staging\"] for the dev cluster that hosts both namespaces."
  type        = list(string)
  default     = []
}
