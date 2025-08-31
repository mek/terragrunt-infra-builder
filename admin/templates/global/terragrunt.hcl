# Global Resources Configuration for Environment: {{env_name}}
# This file manages resources that are shared across all regions in the environment

include "root" {
  path = find_in_parent_folders()
}

# Global resources that span multiple regions
terraform {
  source = "../../../modules/global"
}

# Environment-specific inputs
inputs = {
  environment = "{{env_name}}"
  
  # Global resource settings
  enable_global_monitoring = true
  enable_global_logging    = true
  
  # Global tags
  global_tags = {
    Environment = "{{env_name}}"
    Scope       = "global"
    ManagedBy   = "terragrunt"
  }
  
  # Global resource configurations
  global_resources = {
    # IAM roles and policies
    create_global_iam_roles = true
    create_global_policies = true
    
    # CloudWatch and monitoring
    create_global_monitoring = true
    create_global_alarms     = true
    
    # Global networking
    create_global_vpc_peering = false
    create_global_transit_gateway = false
  }
}
