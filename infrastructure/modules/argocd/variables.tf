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
