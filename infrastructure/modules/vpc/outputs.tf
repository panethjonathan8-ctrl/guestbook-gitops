output "vpc_id" {
  description = "ID of the created VPC. Consumed by eks, addons, and rds."
  value       = module.this.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets. Consumed by eks for node placement."
  value       = module.this.public_subnets
}

output "private_subnets" {
  description = "IDs of the private subnets. Consumed by rds for the DB subnet group."
  value       = module.this.private_subnets
}
