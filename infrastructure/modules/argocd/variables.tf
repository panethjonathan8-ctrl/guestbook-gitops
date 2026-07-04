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

variable "enable_sso" {
  description = "Whether to configure ArgoCD for GitHub SSO (server.insecure + Dex GitHub connector + RBAC allow-list). Prod-only — dev has no public Ingress in front of ArgoCD, so this defaults to false. See issue #53."
  type        = bool
  default     = false
}

variable "sso_hostname" {
  description = "Public hostname ArgoCD is reachable at, e.g. argocd.guestbookinterview.lol. Used to build the OAuth redirect URL. Only required when enable_sso is true."
  type        = string
  default     = null
}

variable "sso_admin_email" {
  description = "The single email address granted role:admin via RBAC when SSO is enabled. Must match the 'email' claim Dex receives from GitHub, NOT the GitHub username/login — ArgoCD's RBAC matches SSO identities on the sub/email/groups claims, and Dex's GitHub connector returns an opaque sub and no groups (no org configured), so email is the only reliably matchable claim. Every other GitHub login authenticates successfully but gets zero access (policy.default is empty). Only required when enable_sso is true."
  type        = string
  default     = null
}

variable "sso_admin_sub" {
  description = "The literal opaque 'sub' claim value Dex's GitHub connector issues for the admin's GitHub account (visible in argocd-server request logs, e.g. 'CgkyNTIxNDgxNzUSBmdpdGh1Yg'). Granted role:admin alongside sso_admin_email (issue #78) as a defense-in-depth binding — see comment in main.tf for why both are bound. Only required when enable_sso is true."
  type        = string
  default     = null
}
