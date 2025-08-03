output "lambda_functions" {
  description = "Map of Lambda function details"
  value = {
    for k, v in aws_lambda_function.this : k => {
      function_name = v.function_name
      invoke_arn    = v.invoke_arn
      arn           = v.arn
    }
  }
}

output "shared_layer_arn" {
  description = "ARN of the shared dependencies layer"
  value       = aws_lambda_layer_version.shared_dependencies.arn
}