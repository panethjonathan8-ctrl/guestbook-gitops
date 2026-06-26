include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/github-oidc"
}

dependency "ecr" {
  config_path = "../ecr"

  mock_outputs = {
    repository_arn = "arn:aws:ecr:eu-west-1:400013494612:repository/guestbook"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  role_name          = "guestbook-github-actions"
  github_repo        = "panethjonathan8-ctrl/guestbook-app"
  ecr_repository_arn = dependency.ecr.outputs.repository_arn
}
