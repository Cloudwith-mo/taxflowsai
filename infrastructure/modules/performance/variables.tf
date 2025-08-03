variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain for CloudFront"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for CloudFront"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "dynamodb_min_read_capacity" {
  description = "Minimum read capacity for DynamoDB"
  type        = number
  default     = 5
}

variable "dynamodb_max_read_capacity" {
  description = "Maximum read capacity for DynamoDB"
  type        = number
  default     = 100
}

variable "dynamodb_min_write_capacity" {
  description = "Minimum write capacity for DynamoDB"
  type        = number
  default     = 5
}

variable "dynamodb_max_write_capacity" {
  description = "Maximum write capacity for DynamoDB"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}