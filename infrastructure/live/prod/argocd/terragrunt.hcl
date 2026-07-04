include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "argocd" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/argocd.hcl"
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

inputs = {
  cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
  cluster_ca        = dependency.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

  # Prod-only: GitHub SSO via Dex + RBAC allow-list. See issue #53.
  enable_sso      = true
  sso_hostname    = "argocd.guestbookinterview.lol"
  sso_admin_email = "panethjonathan8@gmail.com"
  # Bound alongside sso_admin_email as a defense-in-depth RBAC binding — see
  # issue #78 and the comment in modules/argocd/main.tf for why.
  sso_admin_sub = "CgkyNTIxNDgxNzUSBmdpdGh1Yg"
}
