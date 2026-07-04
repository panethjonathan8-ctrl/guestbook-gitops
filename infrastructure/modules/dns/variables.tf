variable "domain_name" {
  description = "Root domain the hosted zone and wildcard certificate are created for, e.g. guestbookinterview.lol."
  type        = string
}

variable "tags" {
  description = "Tags applied to the hosted zone and certificate. This module is account-level (shared across environments), so no Environment tag is added here."
  type        = map(string)
  default     = {}
}
