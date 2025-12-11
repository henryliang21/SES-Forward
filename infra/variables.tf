variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "SESEmailForwarder"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "forward_to_email" {
  description = "Email address to forward all received emails to"
  type        = string
  sensitive   = true
}

variable "ses_email_bucket" {
  description = "S3 bucket name where SES stores incoming emails"
  type        = string
}

variable "ses_s3_prefix" {
  description = "S3 object key prefix for emails stored by SES (e.g., 'emails/')"
  type        = string
  default     = ""
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "SES-Email-Forwarder"
    ManagedBy = "Terraform"
  }
}
