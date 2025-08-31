# Variables for external S3 backend data module

variable "s3_bucket_name" {
  description = "Name of the external S3 bucket used for Terraform state"
  type        = string
  validation {
    condition = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.s3_bucket_name)) || var.s3_bucket_name == "REPLACE_WITH_ACTUAL_BUCKET_NAME"
    error_message = "S3 bucket name must be valid or the placeholder text."
  }
}

variable "s3_bucket_region" {
  description = "Region of the external S3 bucket"
  type        = string
  default     = "us-east-1"
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.s3_bucket_region))
    error_message = "S3 bucket region must be a valid AWS region."
  }
}

variable "dynamodb_table_name" {
  description = "Name of the external DynamoDB table used for state locking"
  type        = string
  default     = "REPLACE_WITH_ACTUAL_TABLE_NAME"
  validation {
    condition = can(regex("^[a-zA-Z0-9_.-]+$", var.dynamodb_table_name)) || var.dynamodb_table_name == "REPLACE_WITH_ACTUAL_TABLE_NAME"
    error_message = "DynamoDB table name must be valid or the placeholder text."
  }
}

variable "dynamodb_table_region" {
  description = "Region of the external DynamoDB table"
  type        = string
  default     = "us-east-1"
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.dynamodb_table_region))
    error_message = "DynamoDB table region must be a valid AWS region."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (optional)"
  type        = string
  default     = ""
  validation {
    condition = var.kms_key_id == "" || can(regex("^(arn:aws:kms:|alias/|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*$", var.kms_key_id))
    error_message = "KMS key ID must be empty or a valid KMS key identifier (ARN, alias, or key ID)."
  }
}

variable "state_key_prefix" {
  description = "Optional prefix for state keys in the S3 bucket"
  type        = string
  default     = ""
  validation {
    condition = var.state_key_prefix == "" || can(regex("^[a-zA-Z0-9!_.*'()-/]*$", var.state_key_prefix))
    error_message = "State key prefix must be empty or contain only valid S3 key characters."
  }
}

variable "validate_bucket_versioning" {
  description = "Whether to validate that bucket versioning is enabled"
  type        = bool
  default     = true
}

variable "validate_bucket_encryption" {
  description = "Whether to validate that bucket encryption is enabled"
  type        = bool
  default     = true
}

variable "validate_dynamodb_table" {
  description = "Whether to validate that DynamoDB table exists and is accessible"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}