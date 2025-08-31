# Variables for external VPC data module

variable "vpc_id" {
  description = "ID of the external VPC"
  type        = string
  validation {
    condition = can(regex("^vpc-[0-9a-f]+$", var.vpc_id)) || var.vpc_id == "REPLACE_WITH_ACTUAL_VPC_ID"
    error_message = "VPC ID must be in format vpc-xxxxxx or the placeholder text."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the external VPC"
  type        = string
  default     = "REPLACE_WITH_VPC_CIDR"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id)) || can(regex("^REPLACE_WITH_", id))
    ])
    error_message = "All subnet IDs must be in format subnet-xxxxxx or placeholder text."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for id in var.public_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id)) || can(regex("^REPLACE_WITH_", id))
    ])
    error_message = "All subnet IDs must be in format subnet-xxxxxx or placeholder text."
  }
}

variable "database_subnet_ids" {
  description = "List of database subnet IDs"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for id in var.database_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id)) || can(regex("^REPLACE_WITH_", id))
    ])
    error_message = "All subnet IDs must be in format subnet-xxxxxx or placeholder text."
  }
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "internet_gateway_id" {
  description = "Internet gateway ID (optional)"
  type        = string
  default     = ""
  validation {
    condition = var.internet_gateway_id == "" || can(regex("^igw-[0-9a-f]+$", var.internet_gateway_id))
    error_message = "Internet Gateway ID must be in format igw-xxxxxx or empty."
  }
}

variable "nat_gateway_ids" {
  description = "List of NAT gateway IDs (optional)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for id in var.nat_gateway_ids : can(regex("^nat-[0-9a-f]+$", id))
    ])
    error_message = "All NAT Gateway IDs must be in format nat-xxxxxx."
  }
}

variable "route_table_ids" {
  description = "List of route table IDs (optional)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for id in var.route_table_ids : can(regex("^rtb-[0-9a-f]+$", id))
    ])
    error_message = "All route table IDs must be in format rtb-xxxxxx."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}