# Zone Configuration for {{zone_name}} in Region: {{region_name}} of Environment: {{env_name}}
# This file manages resources specific to an availability zone

include "root" {
  path = find_in_parent_folders()
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

# Zone-specific resources
terraform {
  source = "../../../../modules/zone"
}

# Zone-specific inputs
inputs = {
  zone_name   = "{{zone_name}}"
  region_name = "{{region_name}}"
  environment = "{{env_name}}"
  
  # Zone-specific tags
  zone_tags = {
    Environment = "{{env_name}}"
    Region      = "{{region_name}}"
    Zone        = "{{zone_name}}"
    ManagedBy   = "terragrunt"
    Project     = "h2g2"
  }
  
  # Zone-specific settings
  zone_settings = {
    # Enable/disable features based on zone
    enable_zone_monitoring = true
    enable_zone_logging    = true
    
    # Zone resource sizing
    zone_instance_type = "{{env_name}}" == "prod" ? "t3.medium" : "t3.micro"
    zone_disk_size     = "{{env_name}}" == "prod" ? 100 : 50
    
    # Zone networking
    zone_subnet_cidr = "10.0.{{zone_name =~ /z1/ ? '1' : zone_name =~ /z2/ ? '2' : '3'}}.{{zone_name =~ /[ab]/ ? '0' : zone_name =~ /[cd]/ ? '64' : '128'}}/26"
    
    # Zone-specific features
    enable_zone_autoscaling = true
    enable_zone_loadbalancer = true
  }
  
  # Dependencies on regional resources
  depends_on = [
    "regional_vpc",
    "regional_security_groups",
    "regional_iam_roles"
  ]
}
