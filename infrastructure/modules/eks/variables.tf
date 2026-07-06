variable "name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version."
  type        = string
}

variable "region" {
  description = "AWS region the cluster is created in. Required by AWS provider v6."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the cluster and its nodes are placed into."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the control plane ENIs and managed node groups."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the cluster API server publicly so kubectl works from outside the VPC."
  type        = bool
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the Terraform caller cluster-admin automatically. Kept false here — admin access is granted explicitly via access_entries instead, to avoid a 409 conflict on the same principal."
  type        = bool
}

variable "create_cloudwatch_log_group" {
  description = "Create a CloudWatch log group for control plane logs."
  type        = bool
}

variable "enabled_log_types" {
  description = "Which control plane log types to ship to CloudWatch. Empty — logging is disabled for this project."
  type        = list(string)
}

variable "create_kms_key" {
  description = "Create a dedicated KMS key for EKS secrets encryption."
  type        = bool
}

variable "encryption_config" {
  description = "Secrets encryption configuration. Pass null (not {}) to fully disable the encryption block — AWS provider v6 rejects {} with a null key_arn."
  type        = any
  default     = null
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions (instance types, scaling, bootstrap config)."
  type        = any
}

variable "addons" {
  description = "Map of EKS addon configurations (coredns, kube-proxy, vpc-cni, etc)."
  type        = any
}

variable "access_entries" {
  description = "Map of IAM principals granted access to the cluster via EKS access entries."
  type        = any
  default     = {}
}

variable "tags" {
  description = "Common tags applied to all resources this module creates."
  type        = map(string)
  default     = {}
}
