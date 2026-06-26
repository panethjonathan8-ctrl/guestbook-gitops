variable "role_name" {
  type        = string
  description = "Name of the IAM role GitHub Actions will assume."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in owner/repo format. Scopes which repo can assume the role."
}

variable "ecr_repository_arn" {
  type        = string
  description = "ARN of the ECR repository the role is allowed to push images to."
}
