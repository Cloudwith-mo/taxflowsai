output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "lambda_functions" {
  description = "Lambda function details"
  value       = module.lambda.lambda_functions
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.metadata.name
}