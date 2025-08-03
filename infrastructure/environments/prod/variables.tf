variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1)."
  }
}

variable "domain_name" {
  description = "Domain name for CORS configuration"
  type        = string
  default     = "https://taxflowsai.com"
  
  validation {
    condition     = can(regex("^https://", var.domain_name))
    error_message = "Domain name must start with https://."
  }
}

variable "upload_bucket_name" {
  description = "S3 bucket name for file uploads"
  type        = string
  default     = "taxflowsai-uploads"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.upload_bucket_name))
    error_message = "Bucket name must be valid S3 bucket name format."
  }
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for metadata"
  type        = string
  default     = "TaxFlowsAI_Metadata"
}

variable "artifact_bucket" {
  description = "S3 bucket name for CodePipeline artifacts"
  type        = string
  default     = "taxflowsai-pipeline-artifacts-0737"
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection for GitHub"
  type        = string
  sensitive   = true
}

variable "repository" {
  description = "GitHub repository in 'owner/name' format"
  type        = string
  default     = "Cloudwith-mo/taxflowsai"
}

variable "branch" {
  description = "Git branch to track"
  type        = string
  default     = "main"
}

variable "alert_email_addresses" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for CloudFront"
  type        = string
  default     = ""
}