# Shared Lambda layer for common dependencies
resource "aws_lambda_layer_version" "shared_dependencies" {
  filename         = var.shared_layer_path
  layer_name       = "${var.project_name}-shared-deps-${var.environment}"
  source_code_hash = filebase64sha256(var.shared_layer_path)
  
  compatible_runtimes = ["python3.12"]
  description         = "Shared dependencies for TaxFlowsAI Lambda functions"
}

# Lambda function resource
resource "aws_lambda_function" "this" {
  for_each = var.lambda_functions

  function_name    = "${var.project_name}-${each.key}-${var.environment}"
  runtime          = each.value.runtime
  role             = var.lambda_role_arn
  handler          = each.value.handler
  filename         = each.value.source_path
  source_code_hash = filebase64sha256(each.value.source_path)
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layers           = [aws_lambda_layer_version.shared_dependencies.arn]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = merge(
      var.common_environment_variables,
      each.value.environment_variables,
      {
        _X_AMZN_TRACE_ID = "Root=1-5e1b4151-5ac6c58b5b5c5b5c5b5c5b5c"
      }
    )
  }

  tags = var.tags

  depends_on = [aws_lambda_layer_version.shared_dependencies]
}