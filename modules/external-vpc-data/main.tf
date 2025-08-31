# External VPC Data Module
# This module provides data sources for external VPCs and outputs the information
# in a format compatible with other terraform-aws-modules

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Data source for VPC lookup (for validation and additional info)
data "aws_vpc" "external" {
  id = var.vpc_id
}

# Data sources for subnets (for validation)
data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

data "aws_subnet" "public" {
  count = length(var.public_subnet_ids)
  id    = var.public_subnet_ids[count.index]
}

data "aws_subnet" "database" {
  count = length(var.database_subnet_ids)
  id    = var.database_subnet_ids[count.index]
}

# Data source for internet gateway (if provided)
data "aws_internet_gateway" "external" {
  count = var.internet_gateway_id != "" ? 1 : 0
  id    = var.internet_gateway_id
}

# Data sources for NAT gateways (if provided)
data "aws_nat_gateway" "external" {
  count = length(var.nat_gateway_ids)
  id    = var.nat_gateway_ids[count.index]
}

# Local calculations and validations
locals {
  # Verify all subnets belong to the VPC
  private_vpc_ids = [for subnet in data.aws_subnet.private : subnet.vpc_id]
  public_vpc_ids  = [for subnet in data.aws_subnet.public : subnet.vpc_id]
  database_vpc_ids = [for subnet in data.aws_subnet.database : subnet.vpc_id]
  
  # Extract actual CIDR blocks from data sources for validation
  actual_vpc_cidr = data.aws_vpc.external.cidr_block
  actual_private_cidrs = [for subnet in data.aws_subnet.private : subnet.cidr_block]
  actual_public_cidrs  = [for subnet in data.aws_subnet.public : subnet.cidr_block]
  actual_database_cidrs = [for subnet in data.aws_subnet.database : subnet.cidr_block]
  
  # Extract actual availability zones
  actual_private_azs = [for subnet in data.aws_subnet.private : subnet.availability_zone]
  actual_public_azs  = [for subnet in data.aws_subnet.public : subnet.availability_zone]
  actual_database_azs = [for subnet in data.aws_subnet.database : subnet.availability_zone]
}

# Validation checks
resource "null_resource" "vpc_validation" {
  # Verify VPC exists and CIDR matches (if provided)
  lifecycle {
    precondition {
      condition = data.aws_vpc.external.id == var.vpc_id
      error_message = "VPC ${var.vpc_id} not found or inaccessible."
    }
    
    precondition {
      condition = var.vpc_cidr == "REPLACE_WITH_VPC_CIDR" || var.vpc_cidr == local.actual_vpc_cidr
      error_message = "VPC CIDR mismatch: expected ${var.vpc_cidr}, actual ${local.actual_vpc_cidr}"
    }
  }
  
  # Trigger recreation if configuration changes
  triggers = {
    vpc_id = var.vpc_id
    vpc_cidr = var.vpc_cidr
    private_subnets = join(",", var.private_subnet_ids)
    public_subnets = join(",", var.public_subnet_ids)
    database_subnets = join(",", var.database_subnet_ids)
  }
}