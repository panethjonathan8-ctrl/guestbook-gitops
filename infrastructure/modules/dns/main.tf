terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The hosted zone is AWS's authoritative DNS server for this domain.
# Creating it does NOT make it live on the internet by itself — the domain
# registrar (GoDaddy) still points at its own nameservers until we copy the
# four name_servers this resource generates into GoDaddy's NS records for the
# domain. Only after that delegation propagates does a lookup for
# "argocd.guestbookinterview.lol" actually reach this zone.
resource "aws_route53_zone" "this" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = var.domain_name
  })
}

# Wildcard cert covers every subdomain (argocd., grafana., dev., etc.) with a
# single certificate instead of requesting one per subdomain. The apex domain
# itself is added as a Subject Alternative Name in case something is ever
# served directly at guestbookinterview.lol with no subdomain.
resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "*.${var.domain_name}"
  })
}

# DNS validation proves domain ownership by asking us to create a specific
# CNAME record ACM generates. Because the hosted zone above already exists in
# the same AWS account, this can be fully automated — no manual step, unlike
# email validation.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Blocks until ACM confirms the validation records above have been seen and
# the certificate has moved from PENDING_VALIDATION to ISSUED. Any resource
# that needs the certificate ARN (e.g. an ALB listener) should depend on this,
# not on aws_acm_certificate.wildcard directly, so it never tries to use a
# certificate that isn't actually valid yet.
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
