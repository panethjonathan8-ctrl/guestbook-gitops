output "role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN to set as the AWS_ROLE_ARN repo variable in guestbook-app."
}
