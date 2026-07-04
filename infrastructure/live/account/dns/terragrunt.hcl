include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/dns"
}

inputs = {
  domain_name = "guestbookinterview.lol"

  tags = {
    Project   = "guestbook"
    ManagedBy = "terragrunt"
  }
}
