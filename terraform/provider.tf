terraform {
  backend "s3" {
    bucket  = "taxflowsai-terraform-state"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
