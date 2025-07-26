variable "region" {
  description = "AWS region to deploy into" 
}

variable "artifact_bucket" {
  description = "S3 bucket for CodePipeline artifacts"
}


variable "codestar_connection_arn" {
  type        = string
  description = "ARN of CodeStar Connection to GitHub"
}
