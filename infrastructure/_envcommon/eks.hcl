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
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/eks"
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
  #
  # NOTE (issue #84): this used to be named cluster_enabled_log_types, which
  # is not a real input on terraform-aws-modules/eks/aws — Terragrunt passes
  # `inputs` as TF_VAR_* env vars, and an unmatched TF_VAR_* is silently
  # ignored rather than erroring. That meant this line did nothing, and the
  # module's own default (["audit","api","authenticator"]) was silently in
  # effect the whole time, with EKS auto-creating an unmanaged CloudWatch Log
  # Group to receive them. The corrected name below actually disables it.
  create_cloudwatch_log_group = false
  enabled_log_types           = []

  # No KMS key — dev cluster does not need secrets encryption.
  create_kms_key     = false
  # null tells the module enable_encryption_config = false, skipping the block.
  # Default is {} (not null) which renders the block with a null key_arn — AWS
  # provider v6 rejects that. Explicit null is the correct way to disable it.
  encryption_config  = null

  eks_managed_node_groups = {
    guestbook = {
      instance_types = ["t3.medium"]
      # 2 nodes for now. Prefix delegation (below) removes the old 17-pod-
      # per-node ceiling that used to force this count; 2 nodes is now sized
      # for CPU/memory, not pod slots.
      min_size       = 1
      max_size       = 2
      desired_size   = 2

      # AL2023 nodes use the "nodeadm" bootstrap, not the older bootstrap.sh
      # script — kubelet flags are set via a NodeConfig cloud-init document,
      # not bootstrap_extra_args (that path is Bottlerocket-only). Without
      # this, kubelet's own --max-pods stays at the static per-instance-type
      # table value (17 for t3.medium) even with CNI prefix delegation
      # enabled — the CNI and kubelet compute their pod ceilings separately.
      # 110 matches Kubernetes' own recommended per-node pod ceiling.
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  maxPods: 110
          EOT
        }
      ]
    }
  }

  addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    # before_compute = true places vpc-cni in a separate resource that has NO
    # depends_on on node groups. Without this, nodes try to join before the CNI
    # DaemonSet is running, kubelet reports "cni plugin not initialized", and the
    # node group fails with CREATE_FAILED after 33 minutes.
    #
    # configuration_values enables prefix delegation: instead of handing out
    # one IP per ENI slot (t3.medium's 3 ENIs x 6 IPs - 1 primary = 17 pods
    # max, regardless of free CPU/memory), the CNI assigns a /28 (16 IPs) per
    # slot, raising the ceiling to 110+ pods per node. Free — no new AWS
    # resources, just a setting on an addon that's already deployed.
    vpc-cni = {
      most_recent          = true
      before_compute       = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
  }

  # Grant cluster-admin to the guestbook-dev IAM user and the GitHub Actions CI role.
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
    github_actions = {
      principal_arn = "arn:aws:iam::${local.account_id}:role/guestbook-github-actions"
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
