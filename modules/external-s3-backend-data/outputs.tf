# Outputs for external S3 backend data module
# These outputs provide information about the external S3 backend
# in a format that can be used by the root terragrunt.hcl configuration

# S3 bucket outputs
output "s3_bucket_name" {
  description = "Name of the external S3 bucket"
  value       = local.bucket_name
}

output "s3_bucket_region" {
  description = "Region of the external S3 bucket"
  value       = local.bucket_region
}

output "s3_bucket_arn" {
  description = "ARN of the external S3 bucket"
  value       = local.bucket_arn
}

# DynamoDB table outputs
output "dynamodb_table_name" {
  description = "Name of the external DynamoDB table"
  value       = local.dynamodb_table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the external DynamoDB table"
  value       = local.dynamodb_table_arn
}

output "dynamodb_table_region" {
  description = "Region of the external DynamoDB table"
  value       = var.dynamodb_table_region
}

# Backend configuration outputs
output "backend_config" {
  description = "Complete backend configuration for use in terragrunt.hcl"
  value = {
    backend = "s3"
    config = {
      encrypt        = true
      bucket         = local.bucket_name
      region         = local.bucket_region
      dynamodb_table = local.dynamodb_table_name
      
      # Optional KMS key
      kms_key_id = var.kms_key_id != "" ? var.kms_key_id : null
      
      # State key will be set by terragrunt automatically
      key = null
    }
  }
  sensitive = false
}

# Validation status outputs
output "bucket_versioning_enabled" {
  description = "Whether bucket versioning is enabled (null if not validated)"
  value       = local.versioning_enabled
}

output "bucket_encryption_enabled" {
  description = "Whether bucket encryption is enabled (null if not validated)"
  value       = local.encryption_enabled
}

# KMS key outputs
output "kms_key_id" {
  description = "KMS key ID used for encryption (if provided)"
  value       = var.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN (if KMS key is provided and accessible)"
  value       = local.kms_key_arn
}

# Configuration summary for troubleshooting
output "configuration_summary" {
  description = "Summary of the external backend configuration"
  value = {
    s3_bucket = {
      name              = local.bucket_name
      region            = local.bucket_region
      versioning        = local.versioning_enabled
      encryption        = local.encryption_enabled
    }
    dynamodb_table = {
      name   = local.dynamodb_table_name
      region = var.dynamodb_table_region
      exists = length(data.aws_dynamodb_table.backend) > 0
    }
    kms_key = {
      id  = var.kms_key_id
      arn = local.kms_key_arn
    }
    validation = {
      bucket_versioning = var.validate_bucket_versioning
      bucket_encryption = var.validate_bucket_encryption
      dynamodb_table    = var.validate_dynamodb_table
    }
  }
}