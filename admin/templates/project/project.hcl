# Project Configuration: {{name}}
# Type: {{project_type}}
# Created by Terragrunt Management Script

locals {
  # Project identification
  project = "{{project}}"
  project_type = "{{project_type}}"
  
  # Common tags applied to all resources in this project
  common_tags = {{common_tags}}
  
  # Project-specific configuration based on type
  config = {
    # Instance settings
    default_instance_type = "{{default_instance}}"
    min_instances = {{min_instances}}
    
    # Feature toggles
    monitoring_enabled = {{enable_monitoring}}
    auto_scaling_enabled = {{enable_scaling}}
    
    # Security settings
    encryption_at_rest = true
    encryption_in_transit = true
    
    # Project resource limits
    max_instances_per_region = local.project_type == "data" ? 20 : 10
    max_storage_gb = local.project_type == "data" ? 5000 : 1000
    
    # Networking
    vpc_flow_logs_enabled = true
    allowed_ports = local.project_type == "frontend" ? [80, 443] : [22, 80, 443, 8080]
  }
}
