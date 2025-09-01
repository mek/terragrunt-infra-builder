# Terragrunt configuration for {{resource_name}}
# Resource type: s3
# Category: storage
# Environment: {{env_name}}
# Region: {{region_name}}
# Zone: {{zone_name}}
# Generated: 2025-08-31 14:43:18

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
  
  # Load inputs from inputs.json if it exists, otherwise use empty map
  inputs_file_exists = fileexists("${get_terragrunt_dir()}/inputs.json")
  external_inputs = local.inputs_file_exists ? jsondecode(file("${get_terragrunt_dir()}/inputs.json")) : {}
}

terraform {
  # Choose the appropriate source for your s3 resource:
  source = "tfr:///terraform-aws-modules/s3-bucket/aws"
  # source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git"
  # source = "../../modules/s3"
}

inputs = merge(
  # Default inputs - these can be overridden by inputs.json
  {
    # Standard naming convention
    name = "{{full_name}}"
    
    # Common tags applied to all resources
    tags = {
      Environment = local.environment
      Region      = local.aws_region
      Zone        = local.zone
      ManagedBy   = "Terragrunt"
      Resource    = "{{resource_name}}"
      Type        = "s3"
      Category    = "storage"
    }
    
    # TODO: Add s3-specific default configuration here
    # These can be overridden in inputs.json
    
    # Common AWS resource settings
    # vpc_id = dependency.vpc.outputs.vpc_id
    # subnet_ids = dependency.vpc.outputs.private_subnets
    # security_group_ids = [dependency.security_group.outputs.security_group_id]
  },
  
  # External inputs from inputs.json (if it exists)
  # These take precedence over the defaults above
  local.external_inputs
)

# TODO: Add dependencies as needed
# dependency "vpc" {
#   config_path = "{{vpc_path}}"
# }
#
# dependency "security_group" {
#   config_path = "{{sg_path}}"
# }
