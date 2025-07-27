variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "state_key" {
  description = "Path inside the S3 bucket for the .tfstate file"
  type        = string
  default     = "terraform.tfstate"
}

variable "state_region" {
  description = "Region where the state_bucket lives"
  type        = string
  default     = "us-east-1"
}

variable "lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "artifact_bucket" {
  description = "S3 bucket name for CodePipeline artifacts"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar Connection for GitHub → CodePipeline"
  type        = string
}

variable "repository" {
  description = "Git repo in 'owner/name' format"
  type        = string
  default     = "Cloudwith-mo/taxflowsai"
}

variable "branch" {
  description = "Git branch to track in your pipeline"
  type        = string
  default     = "main"
}

variable "lambda_role_name" {
  description = "IAM role name for Lambda"
  type        = string
  default     = "taxflowsai-admin-lambda-role"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "taxflowsai-admin-function"
}

variable "lambda_runtime" {
  description = "Lambda runtime (e.g. nodejs18.x, python3.11)"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_handler" {
  description = "Function entrypoint"
  type        = string
  default     = "index.handler"
}

variable "lambda_package_path" {
  description = "Path to your function deployment package (.zip)"
  type        = string
  default     = "lambda-package.zip"
}

variable "lambda_memory_size" {
  description = "Memory size (MB) for Lambda"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout (seconds) for Lambda"
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Project = "TaxFlowsAI"
    Env     = "prod"
  }
}

# (You can add lambda / API‐GW variables here, e.g. function_name, memory_size, timeouts, tags, etc.)
