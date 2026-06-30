# Shared EKS config — included by live/{env}/eks/terragrunt.hcl.
# vpc_id and subnet_ids are injected by the child file via a dependency block.
locals {
  account      = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env          = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_id   = local.account.locals.account_id
  aws_region   = local.account.locals.aws_region
  env_name     = local.env.locals.env_name
  cluster_name = local.env.locals.cluster_name
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.24.0"
}

inputs = {
  name               = local.cluster_name
  kubernetes_version = "1.36"
  region             = local.aws_region

  # Public endpoint so kubectl works from a laptop.
  # Nodes are already in public subnets so there is no private endpoint needed.
  endpoint_public_access = true

  # Disabled — explicit access_entries block below grants guestbook-dev cluster-admin.
  # Enabling this alongside access_entries for the same principal causes a 409 conflict.
  enable_cluster_creator_admin_permissions = false

  # No CloudWatch logging — not needed for this project.
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # No KMS key — dev cluster does not need secrets encryption.
  create_kms_key     = false
  # null tells the module enable_encryption_config = false, skipping the block.
  # Default is {} (not null) which renders the block with a null key_arn — AWS
  # provider v6 rejects that. Explicit null is the correct way to disable it.
  encryption_config  = null

  eks_managed_node_groups = {
    guestbook = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }

  addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    # before_compute = true places vpc-cni in a separate resource that has NO
    # depends_on on node groups. Without this, nodes try to join before the CNI
    # DaemonSet is running, kubelet reports "cni plugin not initialized", and the
    # node group fails with CREATE_FAILED after 33 minutes.
    vpc-cni            = { most_recent = true, before_compute = true }
  }

  # Grant the guestbook-dev IAM user cluster-admin via EKS access entries.
  # Access entries replace the old aws-auth ConfigMap approach (EKS 1.28+).
  access_entries = {
    guestbook_dev = {
      principal_arn = "arn:aws:iam::${local.account_id}:user/guestbook-dev"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Project     = "guestbook"
    ManagedBy   = "terragrunt"
    Environment = local.env_name
  }
}
