resource "aws_iam_role" "lambda_exec" {
  name = "TaxFlowsAI_AdminLambdaRole_v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow"
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

resource "aws_iam_role_policy_attachment" "lambda_bedrock" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_lambda_function" "get_upload_url" {
  function_name    = "GetUploadUrl"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "getuploadurl.lambda_handler"
  filename         = "lambda/getuploadurl.zip"
  source_code_hash = filebase64sha256("lambda/getuploadurl.zip")
  environment {
    variables = {
      BUCKET_NAME    = "taxflowsai-uploads"
      METADATA_TABLE = "TaxFlowsAI_Metadata"
    }
  }
}

resource "aws_lambda_function" "list_documents" {
  function_name    = "ListDocuments"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "listdocuments.lambda_handler"
  filename         = "lambda/listdocuments.zip"
  source_code_hash = filebase64sha256("lambda/listdocuments.zip")
  environment {
    variables = {
      BUCKET_NAME = "taxflowsai-uploads"
      TABLE_NAME  = "TaxFlowsAI_Metadata"
    }
  }
}

resource "aws_lambda_function" "patch_metadata" {
  function_name    = "PatchBrokenMetadata"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_patch.lambda_handler"
  filename         = "lambda/lambda_patch.zip"
  source_code_hash = filebase64sha256("lambda/lambda_patch.zip")
}

resource "aws_lambda_function" "tag_generator" {
  function_name    = "bedrock-doc-tag-generator"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "tag_generator.lambda_handler"
  filename         = "lambda/tag_generator.zip"
  source_code_hash = filebase64sha256("lambda/tag_generator.zip")
  timeout          = 20
  environment {
    variables = {
      MODEL_ID  = "anthropic.claude-3-sonnet-20240229"
      DDB_TABLE = "TaxFlowsAI_Metadata"
    }
  }
}

resource "aws_lambda_function" "api_authorizer" {
  function_name    = "TaxFlowsAI_API_Authorizer"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "authorizer.lambda_handler"
  filename         = "lambda/authorizer.zip"
  source_code_hash = filebase64sha256("lambda/authorizer.zip")
}

resource "aws_lambda_function" "set_admin_category" {
  function_name    = "SetAdminCategory"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "set_admin_category.lambda_handler"
  filename         = "lambda/set_admin_category.zip"
  source_code_hash = filebase64sha256("lambda/set_admin_category.zip")
}

resource "aws_apigatewayv2_api" "taxflows_api" {
  name          = "TaxFlowsAI-UploadAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins     = ["https://taxflowsai.com"]
    allow_methods     = ["GET", "POST", "OPTIONS", "PUT"]
    allow_headers     = ["Content-Type", "Authorization"]
    expose_headers    = ["*"]
    max_age           = 3600
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id                            = aws_apigatewayv2_api.taxflows_api.id
  name                              = "TaxFlowsAI_LambdaAuthorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.api_authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.taxflows_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_upload_url.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list" {
  api_id                 = aws_apigatewayv2_api.taxflows_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_documents.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "patch" {
  api_id                 = aws_apigatewayv2_api.taxflows_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.patch_metadata.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin" {
  api_id                 = aws_apigatewayv2_api.taxflows_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.set_admin_category.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route_upload" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  route_key          = "POST /GetUploadUrl"
  target             = "integrations/${aws_apigatewayv2_integration.upload.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
}

resource "aws_apigatewayv2_route" "route_list" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  route_key          = "GET /ListDocuments"
  target             = "integrations/${aws_apigatewayv2_integration.list.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
}

resource "aws_apigatewayv2_route" "route_patch" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  route_key          = "POST /PatchBrokenMetadata"
  target             = "integrations/${aws_apigatewayv2_integration.patch.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
}

resource "aws_apigatewayv2_route" "route_admin" {
  api_id             = aws_apigatewayv2_api.taxflows_api.id
  route_key          = "POST /SetAdminCategory"
  target             = "integrations/${aws_apigatewayv2_integration.admin.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.taxflows_api.id
  name        = "default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.taxflows_api.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda_authorizer.id}"
}

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

resource "aws_lambda_permission" "allow_apigw_admin" {
  statement_id  = "AllowAPIGatewayInvokeAdmin"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.set_admin_category.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.taxflows_api.execution_arn}/*/*"
}
