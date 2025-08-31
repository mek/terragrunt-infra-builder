# Outputs for external VPC data module
# These outputs match the format used by terraform-aws-modules/vpc/aws
# for compatibility with existing dependencies

# VPC outputs
output "vpc_id" {
  description = "ID of the external VPC"
  value       = data.aws_vpc.external.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the external VPC"
  value       = data.aws_vpc.external.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the external VPC"
  value       = data.aws_vpc.external.arn
}

# Private subnet outputs
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.private_subnet_ids
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = [for subnet in data.aws_subnet.private : subnet.arn]
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the private subnets"
  value       = [for subnet in data.aws_subnet.private : subnet.cidr_block]
}

# Public subnet outputs
output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = var.public_subnet_ids
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = [for subnet in data.aws_subnet.public : subnet.arn]
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the public subnets"
  value       = [for subnet in data.aws_subnet.public : subnet.cidr_block]
}

# Database subnet outputs
output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = var.database_subnet_ids
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = [for subnet in data.aws_subnet.database : subnet.arn]
}

output "database_subnets_cidr_blocks" {
  description = "List of CIDR blocks of the database subnets"
  value       = [for subnet in data.aws_subnet.database : subnet.cidr_block]
}

# Database subnet group name (commonly needed for RDS)
output "database_subnet_group_name" {
  description = "Name tag of the database subnet group (if available)"
  value       = length(var.database_subnet_ids) > 0 ? "${var.tags.Environment}-${var.tags.Project}-db-subnet-group" : ""
}

# Availability zone outputs
output "azs" {
  description = "A list of availability zones specified as inputs"
  value       = var.availability_zones
}

output "private_subnets_azs" {
  description = "A list of availability zones for private subnets"
  value       = [for subnet in data.aws_subnet.private : subnet.availability_zone]
}

output "public_subnets_azs" {
  description = "A list of availability zones for public subnets"  
  value       = [for subnet in data.aws_subnet.public : subnet.availability_zone]
}

output "database_subnets_azs" {
  description = "A list of availability zones for database subnets"
  value       = [for subnet in data.aws_subnet.database : subnet.availability_zone]
}

# Network infrastructure outputs
output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = var.internet_gateway_id
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = length(data.aws_internet_gateway.external) > 0 ? data.aws_internet_gateway.external[0].arn : ""
}

output "natgw_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = var.nat_gateway_ids
}

output "natgw_arns" {
  description = "List of ARNs of the NAT Gateways"
  value       = [for nat in data.aws_nat_gateway.external : nat.arn]
}

# Route table outputs  
output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value       = var.route_table_ids
}

output "public_route_table_ids" {
  description = "List of IDs of the public route tables"
  value       = var.route_table_ids
}

# Compatibility outputs for common naming patterns
output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC"
  value       = data.aws_vpc.external.main_route_table_id
}

output "vpc_default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = data.aws_vpc.external.default_security_group_id
}

output "vpc_default_network_acl_id" {
  description = "The ID of the default network ACL"
  value       = data.aws_vpc.external.default_network_acl_id
}