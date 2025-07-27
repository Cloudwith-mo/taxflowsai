# terraform.tfvars ─ fill these in (or supply via TF_VAR_*)
region                     = "us-east-1"
state_bucket               = "taxflowsai-terraform-state"
state_key                  = "prod/terraform.tfstate"
state_region               = "us-east-1"
lock_table                 = "taxflowsai-terraform-locks"

artifact_bucket            = "taxflowsai-pipeline-artifacts-0737"
codestar_connection_arn    = "arn:aws:codestar-connections:us-east-1:995805900737:connection/01234567-89ab-cdef-0123-456789abcdef"
repository                 = "Cloudwith-mo/taxflowsai"
branch                     = "main"
