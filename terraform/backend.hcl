# backend.hcl
bucket         = "taxflowsai-terraform-state"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"

encrypt        = true
