include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/ecr/aws?version=2.3.0"
}

inputs = {
  repository_name = "guestbook"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images, expire the rest"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })

  tags = {
    Project   = "guestbook"
    ManagedBy = "terragrunt"
  }
}
