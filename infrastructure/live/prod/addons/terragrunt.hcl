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
    cluster_version                    = "1.36"
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
  cluster_endpoint   = dependency.eks.outputs.cluster_endpoint
  cluster_ca         = dependency.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn  = dependency.eks.outputs.oidc_provider_arn
  kubernetes_version = dependency.eks.outputs.cluster_version

  vpc_id = dependency.vpc.outputs.vpc_id

  # Prod-only: gives Prometheus and Loki real EBS-backed PVCs instead of
  # emptyDir. See issue #65.
  enable_ebs_csi_driver = true

  # Prod-only: keeps Route 53 in sync with the ALB's current DNS name so
  # argocd.guestbookinterview.lol survives a cluster teardown/rebuild. See
  # issue #53.
  enable_external_dns = true
  dns_domain_name     = "guestbookinterview.lol"
  dns_zone_arn        = dependency.dns.outputs.zone_arn
}
