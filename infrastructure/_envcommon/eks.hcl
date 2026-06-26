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

  # Public endpoint so kubectl works from a laptop.
  # Nodes are already in public subnets so there is no private endpoint needed.
  endpoint_public_access = true

  # Automatically grants the IAM identity running terraform cluster-admin access.
  # Without this, even the creator cannot run kubectl after apply.
  enable_cluster_creator_admin_permissions = true

  # Key name becomes the IAM role prefix — must start with "guestbook-"
  # to match the resource ARN scope in guestbook-dev-policy.
  eks_managed_node_groups = {
    guestbook = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
    }
  }

  # KMS key creation requires kms:* permissions not in the scoped IAM policy.
  # Etcd encryption is optional — disable it for this demo cluster.
  create_kms_key = false

  # Disable control plane logging — not needed for a demo cluster and avoids
  # requiring CloudWatch permissions in the scoped IAM policy.
  enabled_log_types = []

  addons = {
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
