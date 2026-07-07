include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "addons" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/addons.hcl"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_endpoint                   = "https://mock.example.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg=="
    oidc_provider_arn                  = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "dns" {
  config_path = "../../account/dns"

  mock_outputs = {
    zone_arn = "arn:aws:route53:::hostedzone/MOCKZONEID"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
  cluster_ca        = dependency.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

  vpc_id = dependency.vpc.outputs.vpc_id

  # Real DNS for dev + staging (shared cluster) instead of the
  # /etc/hosts-only placeholder domain. Same pattern prod already uses.
  # See issue #92.
  enable_external_dns = true
  dns_domain_name     = "guestbookinterview.lol"
  dns_zone_arn        = dependency.dns.outputs.zone_arn
}
