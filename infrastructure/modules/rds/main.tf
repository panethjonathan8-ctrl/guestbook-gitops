# No special characters — @, /, ? and # all break URL parsing when embedded
# in postgresql://user:pass@host/db. A purely alphanumeric password is safe
# in every context and still has 62^32 possible values.
resource "random_password" "db" {
  length           = 32
  special          = false
  override_special = ""
}

# The subnet group tells RDS which subnets it may place the instance into.
# Needs at least two subnets in different AZs even for a Single-AZ instance —
# AWS requires this for failover capability if Multi-AZ is ever enabled later.
resource "aws_db_subnet_group" "db" {
  name       = "guestbook-${var.env_name}"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "guestbook-${var.env_name}"
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

# The RDS firewall. One ingress rule: port 5432 from the EKS node SG only.
# Everything else is denied by default — RDS is not reachable from the internet
# even though it sits in a public subnet, because publicly_accessible = false
# prevents AWS from assigning a public IP.
resource "aws_security_group" "db" {
  name        = "guestbook-${var.env_name}-rds"
  description = "Allow PostgreSQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "guestbook-${var.env_name}-rds"
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_nodes" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from EKS managed nodes"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.node_security_group_id
}

# Egress rule: allow all outbound. Security groups in AWS are stateful —
# responses to allowed ingress are automatically permitted. This rule is
# here for completeness and to silence any compliance scanners that flag
# SGs with no egress rules.
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.db.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_db_instance" "db" {
  identifier = "guestbook-${var.env_name}"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  # Encrypt the EBS volume backing the RDS instance at rest using the
  # default AWS-managed key. Zero cost, zero operational overhead.
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  # No public IP — the instance is reachable only from within the VPC.
  # The EKS node SG rule above is the only permitted path in.
  publicly_accessible = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period

  # skip_final_snapshot = true for dev: fast teardown, no orphaned snapshots.
  # skip_final_snapshot = false for prod: AWS creates a snapshot before destroy
  # so data can be recovered even after a terraform destroy.
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "guestbook-${var.env_name}-final"

  # Prevent accidental deletion via the AWS console or API.
  # Must be set to false before terraform destroy can run on prod.
  deletion_protection = var.deletion_protection

  # Apply parameter/version changes immediately during the apply window
  # rather than waiting for the next scheduled maintenance window.
  # Acceptable for dev; for prod this is false so changes happen during
  # the low-traffic window.
  apply_immediately = var.env_name == "dev" ? true : false

  tags = {
    Name        = "guestbook-${var.env_name}"
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

# The secret container in Secrets Manager. Stores metadata about the secret
# (name, description, tags) but not the value itself — that lives in the
# secret version below. Separating them lets Terraform rotate the value
# without recreating the secret ARN (which ESO references).
resource "aws_secretsmanager_secret" "db" {
  name        = var.secret_name
  description = "RDS PostgreSQL credentials for guestbook ${var.env_name}"

  tags = {
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

# The actual secret value. Stored as JSON so ESO can pull individual fields.
# ESO will extract the "url" field and inject it as DATABASE_URL into the pod.
# The other fields (host, username, password, dbname) are there in case any
# other tool needs them separately — e.g. a migration job that needs host+user
# but not the full URL.
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    url      = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.db.address}:${aws_db_instance.db.port}/${var.db_name}"
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.db.address
    port     = tostring(aws_db_instance.db.port)
    dbname   = var.db_name
  })
}

# ---------------------------------------------------------------------------
# Extra secrets — shared instance, additional environments
# ---------------------------------------------------------------------------

# When multiple environments share one RDS instance (e.g. dev and staging on
# the same cluster), we store the same DATABASE_URL under each environment's
# own secret path. Each environment's ESO then reads its own path without
# cross-reading another environment's secret.
#
# We use for_each over a set so Terraform tracks each secret independently.
# Adding a new name only creates one new resource; removing a name only
# destroys that one secret. Using count would renumber everything on changes.
resource "aws_secretsmanager_secret" "extra" {
  for_each    = toset(var.extra_secret_names)
  name        = each.key
  description = "RDS PostgreSQL credentials for guestbook (shared from ${var.env_name} instance)"

  tags = {
    Project     = "guestbook"
    Environment = var.env_name
    ManagedBy   = "terragrunt"
  }
}

resource "aws_secretsmanager_secret_version" "extra" {
  for_each  = toset(var.extra_secret_names)
  secret_id = aws_secretsmanager_secret.extra[each.key].id

  # Identical DATABASE_URL to the primary secret — same host, same database,
  # same user. The only difference is the Secrets Manager path used by each
  # environment's ESO ExternalSecret to find it.
  secret_string = jsonencode({
    url      = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.db.address}:${aws_db_instance.db.port}/${var.db_name}"
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.db.address
    port     = tostring(aws_db_instance.db.port)
    dbname   = var.db_name
  })
}
