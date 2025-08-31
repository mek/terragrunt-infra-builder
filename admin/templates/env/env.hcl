# Environment Configuration: {{name}}
# Type: {{env_type}}
# Created by Terragrunt Management Script

locals {
  # Environment identification
  environment = "{{environment}}"
  env_type    = "{{env_type}}"
  is_production = {{is_production}}
  
  # Common tags applied to all resources in this environment
  common_tags = {{common_tags}}
  
  # Environment-specific configuration
  config = {
    # Backup retention (days)
    backup_retention = local.is_production ? 30 : 7
    
    # Monitoring settings
    monitoring_enabled = local.is_production ? true : false
    detailed_monitoring = local.is_production ? true : false
    
    # Deletion protection
    deletion_protection = local.is_production ? true : false
    
    # Multi-AZ deployment
    multi_az_enabled = local.is_production ? true : false
    
    # Instance sizes
    default_instance_type = local.is_production ? "t3.large" : "t3.micro"
    
    # Storage settings
    storage_encrypted = true
    storage_type = local.is_production ? "gp3" : "gp2"
  }
}
