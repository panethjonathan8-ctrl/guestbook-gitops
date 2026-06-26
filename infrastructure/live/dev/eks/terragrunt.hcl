include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "eks" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/eks.hcl"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id         = "vpc-00000000"
    public_subnets = ["subnet-00000000", "subnet-00000001"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.public_subnets
}
