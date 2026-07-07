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

  # The dev cluster hosts both the 'dev' and 'staging' namespaces.
  # ESO on this cluster must be allowed to read secrets for both environments.
  # Without this, staging's ExternalSecret would get AccessDenied from Secrets Manager.
  eso_secret_name_prefixes = ["guestbook/dev", "guestbook/staging"]

  # GitHub SSO via Dex + RBAC allow-list, mirroring prod (issue #53/#78).
  # See issue #95. sso_admin_sub is the same value prod uses — it's derived
  # from the Dex connector id ("github") and this GitHub account's numeric
  # user id, not from which OAuth App was used to authenticate, so it does
  # not change between environments.
  enable_sso      = true
  sso_hostname    = "argocddev.guestbookinterview.lol"
  sso_admin_email = "panethjonathan8@gmail.com"
  sso_admin_sub   = "CgkyNTIxNDgxNzUSBmdpdGh1Yg"

  # NOTE: we tried upgrading to argocd_chart_version = "10.1.2" (ArgoCD
  # v3.4.4) in #103/#104 to fix kube-prometheus-stack's ComparisonError
  # (EKS 1.36 has a status field, .status.terminatingReplicas, that predates
  # chart 7.9.0's bundled client-go). The upgrade DID fix that, but broke
  # something worse: no Applications were visible to any SSO-logged-in user
  # afterward, even though the Application objects, RBAC policy (verified
  # via `argocd admin settings rbac can`), and session claims were all
  # confirmed correct. The disconnect is somewhere in how ArgoCD 3.4.4's
  # live gRPC request path resolves claims into an enforcement decision —
  # a deeper bug than was safe to chase under time pressure. Reverted in
  # #106. kube-prometheus-stack's Unknown sync status is an accepted,
  # documented, cosmetic quirk again until this gets revisited.
}
