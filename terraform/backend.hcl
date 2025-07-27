# backend.hcl
bucket         = "taxflowsai-terraform-state"
key            = "prod/terraform.tfstate"
region         = "us-east-1"

encrypt        = true
