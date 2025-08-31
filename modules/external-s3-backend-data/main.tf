# External S3 Backend Data Module
# This module validates and outputs information about external S3 backends
# for Terraform state management

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Data source for S3 bucket validation
data "aws_s3_bucket" "backend" {
  bucket = var.s3_bucket_name
  
  provider = aws.s3_region
}

# Data source for S3 bucket versioning (if validation enabled)
data "aws_s3_bucket_versioning" "backend" {
  count = var.validate_bucket_versioning ? 1 : 0
  
  bucket = var.s3_bucket_name
  provider = aws.s3_region
}

# Data source for S3 bucket encryption (if validation enabled)
data "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  count = var.validate_bucket_encryption ? 1 : 0
  
  bucket = var.s3_bucket_name
  provider = aws.s3_region
}

# Data source for DynamoDB table validation
data "aws_dynamodb_table" "backend" {
  count = var.validate_dynamodb_table && var.dynamodb_table_name != "REPLACE_WITH_ACTUAL_TABLE_NAME" ? 1 : 0
  
  name = var.dynamodb_table_name
  provider = aws.dynamodb_region
}

# Data source for KMS key (if provided)
data "aws_kms_key" "backend" {
  count = var.kms_key_id != "" ? 1 : 0
  
  key_id = var.kms_key_id
}

# Configure providers for different regions
provider "aws" {
  alias  = "s3_region"
  region = var.s3_bucket_region
}

provider "aws" {
  alias  = "dynamodb_region"
  region = var.dynamodb_table_region
}

# Local calculations and validations
locals {
  # Extract bucket information
  bucket_name = data.aws_s3_bucket.backend.bucket
  bucket_region = data.aws_s3_bucket.backend.region
  bucket_arn = data.aws_s3_bucket.backend.arn
  
  # DynamoDB table information
  dynamodb_table_name = var.validate_dynamodb_table && length(data.aws_dynamodb_table.backend) > 0 ? data.aws_dynamodb_table.backend[0].name : var.dynamodb_table_name
  dynamodb_table_arn = var.validate_dynamodb_table && length(data.aws_dynamodb_table.backend) > 0 ? data.aws_dynamodb_table.backend[0].arn : ""
  
  # Versioning status
  versioning_enabled = var.validate_bucket_versioning && length(data.aws_s3_bucket_versioning.backend) > 0 ? data.aws_s3_bucket_versioning.backend[0].versioning_configuration[0].status == "Enabled" : null
  
  # Encryption status  
  encryption_enabled = var.validate_bucket_encryption && length(data.aws_s3_bucket_server_side_encryption_configuration.backend) > 0 ? length(data.aws_s3_bucket_server_side_encryption_configuration.backend[0].rule) > 0 : null
  
  # KMS key information
  kms_key_arn = length(data.aws_kms_key.backend) > 0 ? data.aws_kms_key.backend[0].arn : ""
}

# Validation checks
resource "null_resource" "backend_validation" {
  # Verify bucket exists and is accessible
  lifecycle {
    precondition {
      condition = data.aws_s3_bucket.backend.bucket == var.s3_bucket_name
      error_message = "S3 bucket ${var.s3_bucket_name} not found or inaccessible."
    }
    
    precondition {
      condition = !var.validate_bucket_versioning || (var.validate_bucket_versioning && local.versioning_enabled == true)
      error_message = "S3 bucket ${var.s3_bucket_name} does not have versioning enabled. This is recommended for Terraform state buckets."
    }
    
    precondition {
      condition = !var.validate_bucket_encryption || (var.validate_bucket_encryption && local.encryption_enabled == true)
      error_message = "S3 bucket ${var.s3_bucket_name} does not have server-side encryption enabled. This is recommended for Terraform state buckets."
    }
    
    precondition {
      condition = !var.validate_dynamodb_table || var.dynamodb_table_name == "REPLACE_WITH_ACTUAL_TABLE_NAME" || length(data.aws_dynamodb_table.backend) > 0
      error_message = "DynamoDB table ${var.dynamodb_table_name} not found or inaccessible."
    }
  }
  
  # Trigger recreation if configuration changes
  triggers = {
    bucket_name = var.s3_bucket_name
    bucket_region = var.s3_bucket_region
    dynamodb_table = var.dynamodb_table_name
    dynamodb_region = var.dynamodb_table_region
    kms_key = var.kms_key_id
  }
}