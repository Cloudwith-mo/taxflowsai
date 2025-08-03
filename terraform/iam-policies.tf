# Least-privilege IAM policies
data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:*:table/TaxFlowsAI_Metadata",
      "arn:aws:dynamodb:${var.region}:*:table/TaxFlowsAI_Metadata/index/*"
    ]
  }
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::taxflowsai-uploads/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::taxflowsai-uploads"]
  }
}

resource "aws_iam_policy" "lambda_dynamodb" {
  name   = "TaxFlowsAI-Lambda-DynamoDB"
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

resource "aws_iam_policy" "lambda_s3" {
  name   = "TaxFlowsAI-Lambda-S3"
  policy = data.aws_iam_policy_document.lambda_s3.json
}