# Region Configuration: {{name}}
# Environment: {{env_name}}
# Created by Terragrunt Management Script

locals {
  # Region identification
  region = "{{region}}"
  aws_region = "{{aws_region}}"
  environment = "{{env_name}}"
  
  # Common tags applied to all resources in this region
  common_tags = {{common_tags}}
  
  # Region-specific configuration
  config = {{region_settings}}
  
  # Availability zones for this region
  availability_zones = {{availability_zones}}
}
