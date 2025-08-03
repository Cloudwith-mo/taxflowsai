terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "prod"
  project_name = "taxflowsai"
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }

  lambda_functions = {
    get-upload-url = {
      handler                = "getuploadurl.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/get-upload-url/function.zip"
      timeout               = 30
      memory_size           = 256
      environment_variables = {
        BUCKET_NAME    = var.upload_bucket_name
        METADATA_TABLE = var.dynamodb_table_name
      }
    }
    list-documents = {
      handler                = "listdocuments.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/list-documents/function.zip"
      timeout               = 30
      memory_size           = 256
      environment_variables = {
        BUCKET_NAME = var.upload_bucket_name
        TABLE_NAME  = var.dynamodb_table_name
      }
    }
    authorizer = {
      handler                = "authorizer.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/authorizer/function.zip"
      timeout               = 10
      memory_size           = 128
      environment_variables = {}
    }
    patch-metadata = {
      handler                = "lambda_patch.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/patch-metadata/function.zip"
      timeout               = 30
      memory_size           = 256
      environment_variables = {}
    }
    tag-generator = {
      handler                = "tag_generator.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/tag-generator/function.zip"
      timeout               = 60
      memory_size           = 512
      environment_variables = {
        MODEL_ID  = "anthropic.claude-3-sonnet-20240229"
        DDB_TABLE = var.dynamodb_table_name
      }
    }
    set-admin-category = {
      handler                = "set_admin_category.lambda_handler"
      runtime               = "python3.12"
      source_path           = "../../../src/lambda/set-admin-category/function.zip"
      timeout               = 30
      memory_size           = 256
      environment_variables = {}
    }
  }
}

# IAM Module
module "iam" {
  source = "../../modules/iam"
  
  project_name = local.project_name
  environment  = local.environment
  region       = var.region
  bucket_name  = var.upload_bucket_name
  tags         = local.common_tags
}

# Lambda Module
module "lambda" {
  source = "../../modules/lambda"
  
  project_name                   = local.project_name
  environment                    = local.environment
  lambda_role_arn               = module.iam.lambda_role_arn
  shared_layer_path             = "../../../src/lambda/shared/layer.zip"
  lambda_functions              = local.lambda_functions
  common_environment_variables  = {
    ENVIRONMENT = local.environment
    LOG_LEVEL   = "INFO"
  }
  tags = local.common_tags
}

# API Gateway Module
module "api_gateway" {
  source = "../../modules/api-gateway"
  
  project_name              = local.project_name
  environment               = local.environment
  cors_origins             = [var.domain_name]
  authorizer_invoke_arn    = module.lambda.lambda_functions["authorizer"].invoke_arn
  authorizer_function_name = module.lambda.lambda_functions["authorizer"].function_name
  
  lambda_integrations = {
    upload = {
      invoke_arn    = module.lambda.lambda_functions["get-upload-url"].invoke_arn
      function_name = module.lambda.lambda_functions["get-upload-url"].function_name
      route_key     = "POST /GetUploadUrl"
    }
    list = {
      invoke_arn    = module.lambda.lambda_functions["list-documents"].invoke_arn
      function_name = module.lambda.lambda_functions["list-documents"].function_name
      route_key     = "GET /ListDocuments"
    }
    patch = {
      invoke_arn    = module.lambda.lambda_functions["patch-metadata"].invoke_arn
      function_name = module.lambda.lambda_functions["patch-metadata"].function_name
      route_key     = "POST /PatchBrokenMetadata"
    }
    admin = {
      invoke_arn    = module.lambda.lambda_functions["set-admin-category"].invoke_arn
      function_name = module.lambda.lambda_functions["set-admin-category"].function_name
      route_key     = "POST /SetAdminCategory"
    }
  }
  
  throttling_rate_limit  = 1000
  throttling_burst_limit = 2000
  tags                   = local.common_tags
}

# DynamoDB Table
resource "aws_dynamodb_table" "metadata" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

# State lock table
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "terraform-state-lock"
  })
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name           = local.project_name
  environment            = local.environment
  region                 = var.region
  api_name              = module.api_gateway.api_id
  lambda_function_names = [for k, v in module.lambda.lambda_functions : v.function_name]
  dynamodb_table_name   = aws_dynamodb_table.metadata.name
  log_retention_days    = 30
  alert_email_addresses = var.alert_email_addresses
  tags                  = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags
}

# Performance Module
module "performance" {
  source = "../../modules/performance"
  
  project_name               = local.project_name
  environment                = local.environment
  frontend_domain           = "taxflowsai.github.io"
  custom_domain             = var.domain_name
  ssl_certificate_arn       = var.ssl_certificate_arn
  dynamodb_table_name       = aws_dynamodb_table.metadata.name
  dynamodb_min_read_capacity = 5
  dynamodb_max_read_capacity = 100
  tags                      = local.common_tags
}