variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cors_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "authorizer_invoke_arn" {
  description = "Invoke ARN of the authorizer Lambda function"
  type        = string
}

variable "authorizer_function_name" {
  description = "Name of the authorizer Lambda function"
  type        = string
}

variable "lambda_integrations" {
  description = "Map of Lambda integrations"
  type = map(object({
    invoke_arn    = string
    function_name = string
    route_key     = string
  }))
}

variable "throttling_rate_limit" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 1000
}

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 2000
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}