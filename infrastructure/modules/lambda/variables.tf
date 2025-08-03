variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "shared_layer_path" {
  description = "Path to the shared dependencies layer zip file"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda functions to create"
  type = map(object({
    handler                 = string
    runtime                = string
    source_path            = string
    timeout                = number
    memory_size            = number
    environment_variables  = map(string)
  }))
}

variable "common_environment_variables" {
  description = "Common environment variables for all Lambda functions"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}