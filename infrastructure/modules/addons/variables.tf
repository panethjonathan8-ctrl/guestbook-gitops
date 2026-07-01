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
  description = "VPC ID the cluster and ALB live in. Passed to the LBC Helm chart so it knows which VPC to manage resources in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs where the ALB will be placed. Must span at least two AZs."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID of the EKS managed node group. The addons module adds a rule to allow the ALB to reach NGINX on NodePort range (30000-32767)."
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
