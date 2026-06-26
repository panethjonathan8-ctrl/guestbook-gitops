locals {
  account    = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_id = local.account.locals.account_id
  aws_region = local.account.locals.aws_region
}

# Inject an AWS provider into every module — no need to repeat it per module.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

# S3 remote state with native locking (Terraform >= 1.6, no DynamoDB needed).
# The key is derived from the module's path relative to this root config,
# so each module gets its own state file automatically.
remote_state {
  backend = "s3"
  config = {
    bucket       = "guestbook-terraform-state-${local.account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
