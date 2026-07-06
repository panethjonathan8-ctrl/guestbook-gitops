# Thin wrapper around the community EKS module so every building block this
# system is made of — whether we wrote it or not — is discoverable under
# infrastructure/modules/, same as addons/argocd/rds/dns/github-oidc.
module "this" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version
  region             = var.region

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access                   = var.endpoint_public_access
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  create_cloudwatch_log_group = var.create_cloudwatch_log_group
  enabled_log_types           = var.enabled_log_types

  create_kms_key    = var.create_kms_key
  encryption_config = var.encryption_config

  eks_managed_node_groups = var.eks_managed_node_groups
  addons                  = var.addons
  access_entries          = var.access_entries

  tags = var.tags
}
