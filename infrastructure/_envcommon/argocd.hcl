# Shared ArgoCD config — included by live/{env}/argocd/terragrunt.hcl.
# Cluster endpoint and CA are injected by the child file via a dependency
# on the EKS module — the same pattern used by the EKS module depending on VPC.
locals {
  account      = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env          = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region   = local.account.locals.aws_region
  env_name     = local.env.locals.env_name
  cluster_name = local.env.locals.cluster_name
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/argocd"
}

inputs = {
  region          = local.aws_region
  env_name        = local.env_name
  cluster_name    = local.cluster_name
  gitops_repo_url = "https://github.com/panethjonathan8-ctrl/guestbook-gitops.git"
}
