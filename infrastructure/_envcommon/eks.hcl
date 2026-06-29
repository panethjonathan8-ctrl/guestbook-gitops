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
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.33.1"
}

inputs = {
  cluster_name    = local.cluster_name
  cluster_version = "1.36"

  # Public endpoint so kubectl works from a laptop.
  # Nodes are already in public subnets so there is no private endpoint needed.
  cluster_endpoint_public_access = true

  # Disabled — explicit access_entries block below grants guestbook-dev cluster-admin.
  # Enabling this alongside access_entries for the same principal causes a 409 conflict.
  enable_cluster_creator_admin_permissions = false

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }

  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
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
