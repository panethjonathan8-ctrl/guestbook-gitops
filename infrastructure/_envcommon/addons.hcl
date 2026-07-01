# Shared addons config — included by live/{env}/addons/terragrunt.hcl.
# Cluster endpoint, CA, OIDC provider ARN, VPC ID, subnets, and node SG
# are injected by the child file via dependencies on EKS and VPC.
locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env        = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_id = local.account.locals.account_id
  aws_region = local.account.locals.aws_region
  env_name   = local.env.locals.env_name
  cluster_name = local.env.locals.cluster_name
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/addons"
}

inputs = {
  region       = local.aws_region
  account_id   = local.account_id
  env_name     = local.env_name
  cluster_name = local.cluster_name
}
