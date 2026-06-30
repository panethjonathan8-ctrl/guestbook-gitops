include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "rds" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/rds.hcl"
}

# RDS needs subnet IDs from VPC and the node security group ID from EKS.
# The dependency on EKS means RDS always applies after the cluster exists —
# the node SG is created by EKS and its ID is not known until EKS is up.
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

  # Dev sizing: smallest instance, no backups, no deletion protection.
  # This keeps cost low and allows fast teardown with terraform destroy.
  instance_class          = "db.t3.micro"
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
  multi_az                = false

  # Staging shares this RDS instance — same host, same database, same user.
  # A second Secrets Manager secret at guestbook/staging/db-secret holds the
  # same DATABASE_URL so staging's ESO can read its own path independently.
  extra_secret_names = ["guestbook/staging/db-secret"]
}
