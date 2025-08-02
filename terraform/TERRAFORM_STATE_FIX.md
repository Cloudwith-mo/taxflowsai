# Terraform State Backend Fix

## Problem
Your CodePipeline is failing with the error: **"state data in S3 does not have the expected content"**

This happens when the MD5 hash stored in DynamoDB doesn't match the actual S3 state file content.

## Quick Fix (Recommended)

### Option 1: Run the automated fix script
```bash
cd terraform
python3 fix_terraform_state.py
```

### Option 2: Use the bash script
```bash
cd terraform
./fix_state_backend.sh
```

### Option 3: Manual AWS CLI fix
```bash
aws dynamodb delete-item \
    --region us-east-1 \
    --table-name terraform-state-lock \
    --key '{"LockID":{"S":"prod/terraform.tfstate-md5"}}'
```

## What the fix does
1. **Deletes the mismatched digest entry** from DynamoDB
2. **Allows Terraform** to recreate the correct digest on next `terraform init`
3. **Restores consistency** between S3 and DynamoDB

## Automatic Fix in Pipeline
The buildspec has been updated to automatically detect and fix this issue:
- If `terraform init` fails, it runs the fix script
- Then retries `terraform init`
- Pipeline continues normally

## Prevention
- Don't interrupt Terraform operations mid-execution
- Ensure only one Terraform process runs at a time
- Use proper locking mechanisms

## Verification
After applying the fix, run:
```bash
terraform init -backend-config=backend.hcl
```

You should see successful initialization without the digest error.

## Backend Configuration
- **S3 Bucket**: `taxflowsai-terraform-state`
- **State Key**: `prod/terraform.tfstate`
- **DynamoDB Table**: `terraform-state-lock`
- **Region**: `us-east-1`