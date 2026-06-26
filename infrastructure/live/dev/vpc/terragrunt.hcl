include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "vpc" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vpc.hcl"
}
