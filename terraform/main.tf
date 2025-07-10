resource "aws_iam_role" "lambda_exec" {
  name = "TaxFlowsAI_AdminLambdaRole"
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

resource "aws_lambda_function" "pre_signup_set_admin_category" {
  function_name    = "pre_signup_set_admin_category"
  runtime          = "python3.13"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.set_admin_category.lambda_handler"
  filename         = "lambda/set_admin_category.zip"
  source_code_hash = filebase64sha256("lambda/set_admin_category.zip")
}

resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_signup_set_admin_category.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.taxflowsai_user_pool_v2.arn
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

resource "aws_iam_policy" "lambda_bedrock_access" {
  name = "lambda-bedrock-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : ["bedrock:InvokeModel"],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_bedrock" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_bedrock_access.arn
}



resource "aws_cognito_user_pool" "taxflowsai_user_pool_v2" {
  name = "taxflowsai-user-pool-v2"

  auto_verified_attributes = ["email"]

  schema {
    name                = "category"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }

  schema {
    name                = "partner"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }

  lambda_config {
    pre_sign_up = aws_lambda_function.pre_signup_set_admin_category.arn
  }

  lifecycle {
    ignore_changes = [schema]
  }
}



resource "aws_cognito_user_pool_client" "app_client" {
  name         = "taxflowsai-app-client"
  user_pool_id = aws_cognito_user_pool.taxflowsai_user_pool_v2.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

resource "aws_apigatewayv2_api" "taxflows_api" {
  name          = "TaxFlowsAI-UploadAPI"
  protocol_type = "HTTP"
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

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.taxflows_api.id
  name        = "default"
  auto_deploy = true
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

resource "aws_s3_bucket_notification" "trigger_tag_lambda" {
  bucket = "taxflowsai-uploads"

  lambda_function {
    lambda_function_arn = aws_lambda_function.tag_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3_tag]
}

resource "aws_lambda_permission" "allow_s3_tag" {
  statement_id  = "AllowS3ToInvokeTagLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tag_generator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::taxflowsai-uploads"
}
