# Shared VPC config — included by live/{env}/vpc/terragrunt.hcl.
# find_in_parent_folders resolves relative to the INCLUDING file,
# so account.hcl and env.hcl are found correctly for each environment.
locals {
  account      = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env          = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region   = local.account.locals.aws_region
  env_name     = local.env.locals.env_name
  cluster_name = local.env.locals.cluster_name
  vpc_cidr     = local.env.locals.vpc_cidr
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/vpc"
}

inputs = {
  name = "guestbook-${local.env_name}"
  cidr = local.vpc_cidr

  # Two AZs for EKS — it requires at least two for the control plane.
  azs            = ["${local.aws_region}a", "${local.aws_region}b"]
  public_subnets = [cidrsubnet(local.vpc_cidr, 4, 0), cidrsubnet(local.vpc_cidr, 4, 1)]

  # Private subnets for RDS — indices 2 and 3 of the same /4 split so they
  # never overlap with the public subnets (indices 0 and 1).
  # These subnets have no route to the internet gateway, which is exactly
  # what a database needs: reachable from within the VPC, invisible from outside.
  # No NAT gateway required — RDS only accepts inbound connections, it never
  # initiates outbound calls, so there is nothing to NAT.
  private_subnets = [cidrsubnet(local.vpc_cidr, 4, 2), cidrsubnet(local.vpc_cidr, 4, 3)]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true
  enable_dns_hostnames    = true
  enable_dns_support      = true

  # Required for the AWS Load Balancer Controller to discover
  # which subnets to place the ALB into.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  # Tag private subnets so they are identifiable in the AWS console.
  private_subnet_tags = {
    "Tier" = "private"
  }

  tags = {
    Project     = "guestbook"
    ManagedBy   = "terragrunt"
    Environment = local.env_name
  }
}
