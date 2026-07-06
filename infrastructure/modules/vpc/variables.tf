variable "name" {
  description = "Name tag applied to the VPC (e.g. guestbook-dev, guestbook-prod)."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones the public/private subnets are spread across. EKS requires at least two."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for the public subnets (one per AZ). Hosts the ALB and EKS nodes."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for the private subnets (one per AZ). Hosts RDS — no route to the internet gateway."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for private-subnet outbound internet access. False here — RDS never initiates outbound calls, so nothing in the private subnets needs one."
  type        = bool
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign a public IP to instances launched in the public subnets."
  type        = bool
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames within the VPC."
  type        = bool
}

variable "enable_dns_support" {
  description = "Enable DNS resolution within the VPC."
  type        = bool
}

variable "public_subnet_tags" {
  description = "Extra tags on public subnets. Required by the AWS Load Balancer Controller to auto-discover which subnets to place the ALB into."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags on private subnets."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags applied to all resources this module creates."
  type        = map(string)
  default     = {}
}
