# Terragrunt configuration for {{resource_name}}
# Resource type: external-vpc
# Category: networking
# Environment: {{env_name}}
# Region: {{region_name}}
# Zone: {{zone_name}}
# Generated: 2025-08-31 10:02:56

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  aws_region = local.region_vars.locals.aws_region
  zone = "{{zone_name}}"
}

terraform {
  source = "../../../../modules/external-vpc-data"
}

inputs = {
  # Common tags applied to resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "external-vpc"
    Category    = "networking"
  }
  
  # External VPC Configuration - replace with actual values
  vpc_id     = "REPLACE_WITH_ACTUAL_VPC_ID"
  vpc_cidr   = "REPLACE_WITH_VPC_CIDR"
  
  # Subnet IDs - update with actual subnet IDs
  private_subnet_ids  = ["REPLACE_WITH_PRIVATE_SUBNET_1", "REPLACE_WITH_PRIVATE_SUBNET_2"]
  public_subnet_ids   = ["REPLACE_WITH_PUBLIC_SUBNET_1", "REPLACE_WITH_PUBLIC_SUBNET_2"]
  database_subnet_ids = []  # Optional - add if you have database subnets
  
  # Subnet CIDR blocks
  private_subnet_cidrs = ["REPLACE_WITH_PRIVATE_CIDR_1", "REPLACE_WITH_PRIVATE_CIDR_2"]
  public_subnet_cidrs  = ["REPLACE_WITH_PUBLIC_CIDR_1", "REPLACE_WITH_PUBLIC_CIDR_2"]
  
  # Availability zones
  availability_zones = ["${local.aws_region}a", "${local.aws_region}b"]
  
  # Optional gateway IDs
  internet_gateway_id = ""  # Optional - add if needed
  nat_gateway_ids     = []  # Optional - add if you have NAT gateways
  route_table_ids     = []  # Optional - add if you need specific route tables
}

# TODO: Add dependencies as needed
# dependency "vpc" {
#   config_path = "{{vpc_path}}"
# }
#
# dependency "security_group" {
#   config_path = "{{sg_path}}"
# }
