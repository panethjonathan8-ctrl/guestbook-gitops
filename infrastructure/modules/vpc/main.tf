terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Thin wrapper around the community VPC module so every building block this
# system is made of — whether we wrote it or not — is discoverable under
# infrastructure/modules/, same as addons/argocd/rds/dns/github-oidc.
module "this" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway      = var.enable_nat_gateway
  map_public_ip_on_launch = var.map_public_ip_on_launch
  enable_dns_hostnames    = var.enable_dns_hostnames
  enable_dns_support      = var.enable_dns_support

  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags

  tags = var.tags
}
