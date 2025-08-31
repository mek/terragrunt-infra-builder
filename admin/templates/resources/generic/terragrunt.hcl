# Terragrunt configuration for {{resource_name}}
# Resource type: {{resource_type}} (using generic template)
# Category: other
# Environment: {{env_name}}
# Region: {{region_name}}
# Zone: {{zone_name}}
# Generated: 2025-08-31 14:40:00

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
  # CUSTOMIZE THIS: Choose the appropriate source for your resource:
  # source = "tfr:///terraform-aws-modules/MODULE_NAME/aws"
  # source = "git::https://github.com/terraform-aws-modules/terraform-aws-MODULE_NAME.git"
  # source = "../../modules/{{resource_type}}"
  source = "../../modules/{{resource_type}}"
}

inputs = {
  # Standard naming convention
  name = "{{full_name}}"
  
  # Common tags applied to all resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "{{resource_type}}"
    Category    = "other"
  }
  
  # TODO: Add {{resource_type}}-specific configuration here
  # Refer to inputs.json for available variables
  # Example configurations:
  
  # Common AWS resource settings
  # vpc_id = dependency.vpc.outputs.vpc_id
  # subnet_ids = dependency.vpc.outputs.private_subnets
  # security_group_ids = [dependency.security_group.outputs.security_group_id]
}

# TODO: Add dependencies as needed
# dependency "vpc" {
#   config_path = "{{vpc_path}}"
# }
#
# dependency "security_group" {
#   config_path = "{{sg_path}}"
# }