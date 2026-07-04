variable "cluster_name" {
  description = "Name of the EKS cluster addons will be installed into."
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
  description = "Environment name (dev, prod) — used for resource naming and tags."
  type        = string
}

variable "account_id" {
  description = "AWS account ID. Used to construct IAM ARNs."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider. Used in the LBC IRSA trust policy."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID passed to the LBC Helm chart so it knows which VPC to manage ALBs in."
  type        = string
}

variable "lbc_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart."
  type        = string
  default     = "1.8.4"
}

variable "nginx_chart_version" {
  description = "Version of the ingress-nginx Helm chart."
  type        = string
  default     = "4.11.4"
}

variable "lbc_namespace" {
  description = "Kubernetes namespace the AWS LBC will be installed into."
  type        = string
  default     = "kube-system"
}

variable "nginx_namespace" {
  description = "Kubernetes namespace the NGINX Ingress Controller will be installed into."
  type        = string
  default     = "ingress-nginx"
}

variable "enable_ebs_csi_driver" {
  description = "Whether to install the AWS EBS CSI driver and a default gp3 StorageClass. Prod-only — dev stays on emptyDir, so this defaults to false."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Kubernetes version of the EKS cluster. Used to resolve the correct EBS CSI driver addon version. Only required when enable_ebs_csi_driver is true."
  type        = string
  default     = null
}

variable "enable_external_dns" {
  description = "Whether to install external-dns and its IRSA role. Prod-only — dev has no stable domain to manage, so this defaults to false."
  type        = bool
  default     = false
}

variable "dns_domain_name" {
  description = "Root domain external-dns is allowed to manage records under, e.g. guestbookinterview.lol. Only required when enable_external_dns is true."
  type        = string
  default     = null
}

variable "dns_zone_arn" {
  description = "ARN of the Route 53 hosted zone external-dns is scoped to. Only required when enable_external_dns is true."
  type        = string
  default     = null
}

variable "external_dns_chart_version" {
  description = "Version of the external-dns Helm chart."
  type        = string
  default     = "1.15.0"
}

variable "external_dns_namespace" {
  description = "Kubernetes namespace external-dns will be installed into."
  type        = string
  default     = "kube-system"
}
