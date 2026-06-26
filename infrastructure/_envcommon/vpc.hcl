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
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.13.0"
}

inputs = {
  name = "guestbook-${local.env_name}"
  cidr = local.vpc_cidr

  # Two AZs for EKS — it requires at least two for the control plane.
  azs            = ["${local.aws_region}a", "${local.aws_region}b"]
  public_subnets = [cidrsubnet(local.vpc_cidr, 4, 0), cidrsubnet(local.vpc_cidr, 4, 1)]

  # No private subnets, no NAT gateway — everything runs in public subnets.
  # Nodes get public IPs via the IGW. Cost saving for an interview/demo project.
  # Production would use private subnets + NAT to avoid direct node exposure.
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

  tags = {
    Project     = "guestbook"
    ManagedBy   = "terragrunt"
    Environment = local.env_name
  }
}
