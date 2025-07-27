variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
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
  description = "GitHub repository in 'owner/name' format"
  type        = string
  default     = "Cloudwith-mo/taxflowsai"
}

variable "branch" {
  description = "Git branch to track in your pipeline"
  type        = string
  default     = "main"
}

variable "api_name" {
  description = "Name of your existing HTTP API in API Gateway"
  type        = string
  default     = "TaxFlowsAI-UploadAPI"
}

variable "common_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project = "TaxFlowsAI"
    Env     = "prod"
  }
}
