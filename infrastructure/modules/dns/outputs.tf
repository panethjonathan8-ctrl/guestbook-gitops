output "zone_id" {
  description = "Route 53 hosted zone ID. Needed by external-dns and by any Route 53 record created outside this module."
  value       = aws_route53_zone.this.zone_id
}

output "zone_arn" {
  description = "ARN of the hosted zone. Used to scope the external-dns IRSA policy to this zone only, not every zone in the account."
  value       = aws_route53_zone.this.arn
}

output "name_servers" {
  description = "The four AWS nameservers for this zone. Copy these into GoDaddy's NS records for guestbookinterview.lol to delegate the domain to Route 53."
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated wildcard ACM certificate for *.guestbookinterview.lol. Reference this from the ALB listener that terminates TLS."
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}
