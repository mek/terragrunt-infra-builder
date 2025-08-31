# This is the root Terragrunt configuration file.
# It contains the backend configuration that is shared by all modules.

# ------------------------------------------------------------------------------
# SMART BACKEND CONFIGURATION  
# ------------------------------------------------------------------------------
# This configuration automatically determines the correct S3 backend settings
# based on the directory hierarchy (envs, projects, regions, zones).
#
# EXTERNAL BACKEND SUPPORT:
# If an external-s3-backend resource exists with backend-config.json, it will
# be used automatically. Otherwise, smart defaults are generated based on hierarchy.

locals {
  # Parse the current path to determine hierarchy level
  path_parts = split("/", path_relative_to_include())
  
  # Determine if this is in an environment or project hierarchy
  is_env_path = length(local.path_parts) > 0 && local.path_parts[0] == "envs"
  is_project_path = length(local.path_parts) > 0 && local.path_parts[0] == "projects"
  
  # Extract hierarchy components
  environment = local.is_env_path && length(local.path_parts) > 1 ? local.path_parts[1] : "global"
  project = (
    local.is_env_path && length(local.path_parts) > 2 ? local.path_parts[2] :
    local.is_project_path && length(local.path_parts) > 1 ? local.path_parts[1] : 
    "default"
  )
  
  # Determine the region from path or default
  region = (
    local.is_env_path && length(local.path_parts) > 3 ? local.path_parts[3] :
    "us-east-1"
  )
  
  # Look for external backend configuration
  # Search for external-s3-backend resources in the current environment/project path
  external_backend_paths = [
    # Look in same environment-project for external backend
    "${get_repo_root()}/envs/${local.environment}/${local.project}/**/external-s3-backend/backend-config.json",
    "${get_repo_root()}/envs/${local.environment}/${local.project}/*/external-s3-backend/backend-config.json",
    # Look in environment level
    "${get_repo_root()}/envs/${local.environment}/*/external-s3-backend/backend-config.json",
    # Look in project level
    "${get_repo_root()}/projects/${local.project}/*/external-s3-backend/backend-config.json"
  ]
  
  # Find first existing external backend config
  external_backend_config_file = try(
    [for path in local.external_backend_paths : path if fileexists(path)][0],
    null
  )
  
  # Load external backend configuration if found
  external_backend_config = local.external_backend_config_file != null ? jsondecode(file(local.external_backend_config_file)) : {}
  
  # Determine if we should use external backend
  use_external_backend = local.external_backend_config_file != null && 
                        local.external_backend_config.s3_bucket_name != null && 
                        local.external_backend_config.s3_bucket_name != "REPLACE_WITH_ACTUAL_BUCKET_NAME"
  
  # Backend configuration - use external if available, otherwise generate smart defaults
  state_bucket = local.use_external_backend ? 
    local.external_backend_config.s3_bucket_name :
    format("%s-%s-terraform-state", 
      local.environment != "global" ? local.environment : "global",
      local.project
    )
  
  lock_table = local.use_external_backend ? 
    local.external_backend_config.dynamodb_table_name :
    format("%s-%s-terraform-locks",
      local.environment != "global" ? local.environment : "global", 
      local.project
    )
  
  backend_region = local.use_external_backend ?
    (local.external_backend_config.s3_bucket_region != null ? local.external_backend_config.s3_bucket_region : local.region) :
    local.region
  
  # KMS key (if external backend specifies one)
  kms_key_id = local.use_external_backend && local.external_backend_config.kms_key_id != null ? 
    local.external_backend_config.kms_key_id : null
  
  # Generate hierarchical state key
  state_key = local.use_external_backend && local.external_backend_config.state_key_prefix != null ? 
    "${local.external_backend_config.state_key_prefix}${path_relative_to_include()}/terraform.tfstate" :
    "${path_relative_to_include()}/terraform.tfstate"
}

# ------------------------------------------------------------------------------
# CONFIGURE TERRAFORM REMOTE STATE
# ------------------------------------------------------------------------------
# This configuration automatically uses the appropriate S3 bucket and DynamoDB table
# based on the directory hierarchy.
remote_state {
  backend = "s3"
  config = merge(
    {
      encrypt        = true
      bucket         = local.state_bucket
      key            = local.state_key
      region         = local.backend_region
      dynamodb_table = local.lock_table

      s3_bucket_tags = {
        Name        = "Terragrunt State Storage"
        Environment = local.environment
        Project     = local.project
        ManagedBy   = "Terragrunt"
        External    = local.use_external_backend ? "true" : "false"
      }

      dynamodb_table_tags = {
        Name        = "Terragrunt Lock Table"
        Environment = local.environment
        Project     = local.project
        ManagedBy   = "Terragrunt"
        External    = local.use_external_backend ? "true" : "false"
      }
    },
    # Add KMS key configuration if external backend specifies one
    local.kms_key_id != null ? { kms_key_id = local.kms_key_id } : {}
  )

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ------------------------------------------------------------------------------
# CONFIGURE PROVIDERS
# ------------------------------------------------------------------------------
# These settings are used to configure the Terraform providers with smart region detection.
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = "${local.region}"  # Automatically determined from path hierarchy

  # You can add other provider configurations here,
  # for example, assuming a role:
  # assume_role {
  #   role_arn = "arn:aws:iam::123456789012:role/terraform"
  # }
}
EOF
}

# ------------------------------------------------------------------------------
# Global Inputs
# ------------------------------------------------------------------------------
# These inputs are automatically passed to all modules and include smart hierarchy detection.
inputs = {
  # Smart hierarchy values automatically detected from directory structure
  environment = local.environment
  project     = local.project
  region      = local.region
  
  # Common naming prefix for consistent resource naming
  name_prefix = "${local.environment}-${local.project}"
  
  # Common tags for all resources
  common_tags = {
    Environment = local.environment
    Project     = local.project
    Region      = local.region
    ManagedBy   = "Terragrunt"
  }
}
