# Zone Configuration: {{name}}
# Region: {{region_name}}
# Environment: {{env_name}}
# Created by Terragrunt Management Script

locals {
  # Zone identification
  zone = "{{zone}}"
  availability_zone = "{{availability_zone}}"
  region = "{{region_name}}"
  environment = "{{env_name}}"
  
  # Common tags applied to all resources in this zone
  common_tags = {{common_tags}}
  
  # Zone-specific configuration
  config = {{zone_settings}}
}