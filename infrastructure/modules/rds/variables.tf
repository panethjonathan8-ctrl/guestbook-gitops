variable "env_name" {
  description = "Environment name (dev, prod) — used for resource naming and tags."
  type        = string
}

variable "region" {
  description = "AWS region the RDS instance will be created in."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the RDS instance will join."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group. Needs at least two subnets in different AZs."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID of the EKS managed node group. RDS will allow port 5432 from this SG only."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database created inside the RDS instance."
  type        = string
  default     = "guestbook"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "guestbook"
}

variable "instance_class" {
  description = "RDS instance type. db.t3.micro (~$13/month) for dev; db.t3.small (~$26/month) for prod if needed."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB. Minimum for gp2 is 20GB."
  type        = number
  default     = 20
}

variable "secret_name" {
  description = "AWS Secrets Manager secret name. Convention: guestbook/{env}/db-secret."
  type        = string
}

variable "skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Set true for dev (cheap teardown), false for prod (data protection)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental RDS deletion. Always false for dev, always true for prod."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups to retain. 0 disables backups (dev). 7 gives a one-week recovery window (prod)."
  type        = number
  default     = 0
}

variable "multi_az" {
  description = "Deploy a standby replica in a second AZ for automatic failover. Doubles cost — false for dev, optional for prod."
  type        = bool
  default     = false
}
