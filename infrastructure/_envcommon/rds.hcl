# Shared RDS config — included by live/{env}/rds/terragrunt.hcl.
# vpc_id, subnet_ids, and node_security_group_id are injected by the
# child file via dependency blocks (vpc and eks).
locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env        = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region = local.account.locals.aws_region
  env_name   = local.env.locals.env_name
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/rds"
}

inputs = {
  env_name    = local.env_name
  region      = local.aws_region
  db_name     = "guestbook"
  db_username = "guestbook"
  secret_name = "guestbook/${local.env_name}/db-secret"
}
