# Terraform project for TaxFlowsAI - Lambda + API Gateway + DynamoDB
# ===============================
# Assumes you're in us-east-1 and using the following real values:
# - S3 Bucket: taxflowsai-uploads
# - Table Name: TaxFlowsAI_Metadata
# - Lambdas: GetUploadUrl, ListDocuments, PatchBrokenMetadata

# ───────────────────────────────────────
provider "aws" {
  region = "us-east-1"
}

# ───────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "TaxFlowsAI_AdminLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ───────────────────────────────────────
# LAMBDA: GetUploadUrl
resource "aws_lambda_function" "get_upload_url" {
  function_name = "GetUploadUrl"
  handler       = "getuploadurl.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "lambda/getuploadurl.zip"
  source_code_hash = filebase64sha256("lambda/getuploadurl.zip")

  environment {
    variables = {
      BUCKET_NAME     = "taxflowsai-uploads"
      METADATA_TABLE  = "TaxFlowsAI_Metadata"
    }
  }
}

# LAMBDA: ListDocuments
resource "aws_lambda_function" "list_documents" {
  function_name = "ListDocuments"
  handler       = "listdocuments.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "lambda/listdocuments.zip"
  source_code_hash = filebase64sha256("lambda/listdocuments.zip")

  environment {
    variables = {
      BUCKET_NAME     = "taxflowsai-uploads"
      TABLE_NAME      = "TaxFlowsAI_Metadata"
    }
  }
}

# LAMBDA: PatchBrokenMetadata
resource "aws_lambda_function" "patch_metadata" {
  function_name = "PatchBrokenMetadata"
  handler       = "lambda_patch.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "lambda/lambda_patch.zip"
  source_code_hash = filebase64sha256("lambda/lambda_patch.zip")
}

# ───────────────────────────────────────
# API Gateway
resource "aws_apigatewayv2_api" "taxflows_api" {
  name          = "TaxFlowsAI-UploadAPI"
  protocol_type = "HTTP"
}

# Integrations
resource "aws_apigatewayv2_integration" "upload" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.get_upload_url.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.list_documents.invoke_arn
  integration_method = "GET"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "patch" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.patch_metadata.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "route_upload" {
  api_id    = aws_apigatewayv2_api.taxflows_api.id
  route_key = "POST /GetUploadUrl"
  target    = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

resource "aws_apigatewayv2_route" "route_list" {
  api_id    = aws_apigatewayv2_api.taxflows_api.id
  route_key = "GET /ListDocuments"
  target    = "integrations/${aws_apigatewayv2_integration.list.id}"
}

resource "aws_apigatewayv2_route" "route_patch" {
  api_id    = aws_apigatewayv2_api.taxflows_api.id
  route_key = "POST /PatchBrokenMetadata"
  target    = "integrations/${aws_apigatewayv2_integration.patch.id}"
}

# Deployment stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.taxflows_api.id
  name        = "default"
  auto_deploy = true
}

# Lambda permissions
resource "aws_lambda_permission" "allow_apigw_upload" {
  statement_id  = "AllowAPIGatewayInvokeUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_upload_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.taxflows_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_list" {
  statement_id  = "AllowAPIGatewayInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_documents.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.taxflows_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_patch" {
  statement_id  = "AllowAPIGatewayInvokePatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.patch_metadata.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.taxflows_api.execution_arn}/*/*"
}
