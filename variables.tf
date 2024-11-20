variable "profile" {
  description = "The AWS CLI profile to use"
  default     = "default"

}

variable "region" {
  description = "The region in which the resources will be deployed"
  default     = "ap-southeast-1"
}

# Note: You must always use the LATEST version of the landing zone schema, or the deployment will fail. You may refer to the following link:
# https://docs.aws.amazon.com/controltower/latest/userguide/landing-zone-schemas.html
variable "landing_zone_version" {
  description = "The version of the landing zone to deploy"
  default     = "3.3"
}

variable "governed_regions" {
  description = "List of governed regions"
  type        = list(string)
  default     = ["ap-northeast-2"]
}

variable "logging_account_email" {
  type        = string
  description = "The email Id for centralized logging account"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.logging_account_email))
    error_message = "The security account email must be a valid email address."
  }
}

variable "logging_account_name" {
  type        = string
  default     = "CentralizedLogging"
  description = "Name for centralized logging account"
}

variable "security_account_email" {
  type        = string
  description = "The email Id for security roles account"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.security_account_email))
    error_message = "The security account email must be a valid email address."
  }
}

variable "security_account_name" {
  type        = string
  default     = "AuditAndSecurity"
  description = "Name for security roles account"
}

# Details for catalog account name and email

variable "catalog_account_email" {
  type        = string
  description = "The email Id for catalog account"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.catalog_account_email))
    error_message = "The catalog account email must be a valid email address."
  }
}

variable "catalog_account_name" {
  type        = string
  default     = "CatalogAccount"
  description = "Name for catalog account"
}

variable "sandbox_ou_name" {
  type        = string
  default     = "Workloads"
  description = "Name for the sandbox OU"

}

variable "logging_bucket_retention_days" {
  type        = number
  default     = 365
  description = "The number of days to retain logs"
}

variable "access_logging_retention_days" {
  type        = number
  default     = 3650
  description = "The number of days to retain access logs"
}

# A lambda function is used to automatically provision Admin access to created accounts.
variable "lambda_runtime" {
  description = "Lambda runtime environment."
  type        = string
  default     = "python3.12"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  all_regions = distinct(concat([var.region], var.governed_regions))
}