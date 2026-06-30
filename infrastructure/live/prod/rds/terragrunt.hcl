include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "rds" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/rds.hcl"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000"
    private_subnets = ["subnet-00000000", "subnet-00000001"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    node_security_group_id = "sg-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vpc_id                 = dependency.vpc.outputs.vpc_id
  subnet_ids             = dependency.vpc.outputs.private_subnets
  node_security_group_id = dependency.eks.outputs.node_security_group_id

  # Production sizing: 7-day backup window, deletion protection on,
  # final snapshot taken before any destroy so data is never lost.
  # To destroy prod RDS you must first run:
  #   terraform apply -var deletion_protection=false
  # then terraform destroy — this is intentional friction.
  instance_class          = "db.t3.micro"
  skip_final_snapshot     = false
  deletion_protection     = true
  backup_retention_period = 7
  multi_az                = false
}
