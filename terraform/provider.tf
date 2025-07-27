terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = var.state_bucket
    key            = var.state_key
    region         = var.state_region
    encrypt        = true
    dynamodb_table = var.lock_table
  }
}

provider "aws" {
  region = var.region
  # You can also add default_tags here if you want:
  # default_tags {
  #   tags = var.common_tags
  # }
}
