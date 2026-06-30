output "db_endpoint" {
  description = "RDS instance hostname (without port). Used to build the connection URL."
  value       = aws_db_instance.db.address
}

output "db_port" {
  description = "RDS instance port. Always 5432 for PostgreSQL."
  value       = aws_db_instance.db.port
}

output "db_name" {
  description = "Name of the database created inside the RDS instance."
  value       = aws_db_instance.db.db_name
}

output "db_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.db.username
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding DATABASE_URL. Referenced in the ESO IRSA policy."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret. Referenced in the ESO ClusterSecretStore."
  value       = aws_secretsmanager_secret.db.name
}

output "security_group_id" {
  description = "ID of the RDS security group."
  value       = aws_security_group.db.id
}
