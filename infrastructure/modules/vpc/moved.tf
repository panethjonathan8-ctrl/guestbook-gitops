# One-time migration map for issue #84: this module used to be sourced
# directly from the registry (terraform.source pointed straight at
# terraform-aws-modules/vpc/aws in _envcommon/vpc.hcl), so every resource
# lived at the top level of state. Wrapping it in module "this" nests every
# resource one level deeper. Without these moved blocks, Terraform would
# plan to destroy and recreate the entire VPC (and everything downstream:
# EKS nodes, RDS, ALBs) instead of recognizing it as the same infrastructure.
# Generated from the real dev/prod state (`terragrunt state list`) — do not
# hand-edit. Safe to leave in place permanently; a moved block is a no-op if
# its "from" address is not found in state.

moved {
  from = aws_default_network_acl.this[0]
  to   = module.this.aws_default_network_acl.this[0]
}

moved {
  from = aws_default_route_table.default[0]
  to   = module.this.aws_default_route_table.default[0]
}

moved {
  from = aws_default_security_group.this[0]
  to   = module.this.aws_default_security_group.this[0]
}

moved {
  from = aws_internet_gateway.this[0]
  to   = module.this.aws_internet_gateway.this[0]
}

moved {
  from = aws_route.public_internet_gateway[0]
  to   = module.this.aws_route.public_internet_gateway[0]
}

moved {
  from = aws_route_table.private[0]
  to   = module.this.aws_route_table.private[0]
}

moved {
  from = aws_route_table.private[1]
  to   = module.this.aws_route_table.private[1]
}

moved {
  from = aws_route_table.public[0]
  to   = module.this.aws_route_table.public[0]
}

moved {
  from = aws_route_table_association.private[0]
  to   = module.this.aws_route_table_association.private[0]
}

moved {
  from = aws_route_table_association.private[1]
  to   = module.this.aws_route_table_association.private[1]
}

moved {
  from = aws_route_table_association.public[0]
  to   = module.this.aws_route_table_association.public[0]
}

moved {
  from = aws_route_table_association.public[1]
  to   = module.this.aws_route_table_association.public[1]
}

moved {
  from = aws_subnet.private[0]
  to   = module.this.aws_subnet.private[0]
}

moved {
  from = aws_subnet.private[1]
  to   = module.this.aws_subnet.private[1]
}

moved {
  from = aws_subnet.public[0]
  to   = module.this.aws_subnet.public[0]
}

moved {
  from = aws_subnet.public[1]
  to   = module.this.aws_subnet.public[1]
}

moved {
  from = aws_vpc.this[0]
  to   = module.this.aws_vpc.this[0]
}
