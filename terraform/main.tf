# ──────────────────────────────────────────────────────────────────────────────
# 1) IAM Assume Role for Lambda
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = "AllowLambdaServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# 2) Attach Managed Policy for DynamoDB Access
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# ──────────────────────────────────────────────────────────────────────────────
# 3) Define Your Lambda Function
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_lambda_function" "admin" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  filename      = var.lambda_package_path
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  tags          = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# 4) API Gateway Permissions (with for_each)
# ──────────────────────────────────────────────────────────────────────────────
locals {
  apigw_methods = [
    { name = "get",    route_key = "GET/items"   },
    { name = "post",   route_key = "POST/items"  },
    { name = "patch",  route_key = "PATCH/items" },
  ]
}

resource "aws_lambda_permission" "apigw" {
  for_each = { for m in local.apigw_methods : m.route_key => m }

  statement_id  = "apigw-${each.value.name}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${each.value.route_key}"
}
