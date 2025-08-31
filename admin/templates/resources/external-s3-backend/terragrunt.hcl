# Terragrunt configuration for {{resource_name}}
# Resource type: external-s3-backend
# Category: storage
# Environment: {{env_name}}
# Region: {{region_name}}
# Zone: {{zone_name}}
# Generated: 2025-08-31 10:04:09

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
  source = "../../../../modules/external-s3-backend-data"
}

inputs = {
  # Common tags applied to resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "external-s3-backend"
    Category    = "storage"
  }
  
  # External S3 Backend Configuration - replace with actual values
  bucket_name = "REPLACE_WITH_ACTUAL_BUCKET_NAME"
  dynamodb_table = "REPLACE_WITH_ACTUAL_DYNAMODB_TABLE"
  kms_key_id = ""  # Optional - add if using KMS encryption
}

# TODO: Add dependencies as needed
# dependency "vpc" {
#   config_path = "{{vpc_path}}"
# }
#
# dependency "security_group" {
#   config_path = "{{sg_path}}"
# }
