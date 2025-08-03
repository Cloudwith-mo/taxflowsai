# CodePipeline IAM Permissions Fix

## Problem Summary
Your CodePipeline is failing during the Terraform plan phase with `AccessDeniedException` errors for:
- `lambda:GetPolicy` on Lambda functions
- `s3:GetBucketWebsite` on artifact S3 bucket

## Root Cause Analysis
The `taxflowsai-codebuild-role-v2` role lacks specific permissions needed by Terraform to read resource configurations during the plan phase.

## Solution Applied

### 1. Updated IAM Policies

**Enhanced `artifact_bucket_access` policy** with additional S3 permissions:
```hcl
# Added these actions to both artifact and state bucket access:
"s3:GetBucketWebsite",
"s3:GetBucketLocation", 
"s3:GetBucketVersioning"
```

**Verified `terraform_permissions` policy** already includes:
```hcl
"lambda:GetPolicy",
"s3:GetBucketWebsite"
```

### 2. Lambda Functions Confirmed
All Lambda functions are managed by Terraform in `main.tf`:
- ✅ TaxFlowsAI_API_Authorizer
- ✅ GetUploadUrl
- ✅ ListDocuments
- ✅ PatchBrokenMetadata
- ✅ bedrock-doc-tag-generator
- ✅ SetAdminCategory

## Quick Fix Commands

### Option 1: Automated Script (Recommended)
```bash
cd terraform
./fix_iam_permissions.sh
```

### Option 2: Manual Terraform Commands
```bash
cd terraform

# Initialize if needed
terraform init -backend-config=backend.hcl

# Apply only the IAM policy changes
terraform apply \
  -target=aws_iam_policy.artifact_bucket_access \
  -target=aws_iam_policy.terraform_permissions \
  -auto-approve
```

### Option 3: Full Plan and Apply (If needed)
```bash
cd terraform
terraform plan -out=fix.tfplan
terraform apply fix.tfplan
```

## Verification Steps

After applying the fix:

1. **Check IAM Policy Updates**:
   ```bash
   aws iam get-policy-version \
     --policy-arn $(aws iam list-policies --query 'Policies[?PolicyName==`taxflowsai-artifact-bucket-access`].Arn' --output text) \
     --version-id v1
   ```

2. **Trigger Pipeline**:
   - Go to AWS CodePipeline console
   - Find `taxflowsai-terraform-pipeline`
   - Click "Release change" to trigger a new run

3. **Monitor Plan Phase**:
   - Watch the "Plan" stage in CodePipeline
   - Check CloudWatch logs for the `taxflowsai-terraform-plan` CodeBuild project

## Expected Outcome

✅ CodePipeline plan phase should complete successfully  
✅ No more `AccessDeniedException` errors  
✅ Terraform plan will generate without permission issues  

## Rollback Plan (If Needed)

If issues occur, revert the IAM policy changes:
```bash
git checkout HEAD~1 -- pipeline.tf
terraform apply -target=aws_iam_policy.artifact_bucket_access -auto-approve
```

## Next Steps

1. Run the fix script: `./fix_iam_permissions.sh`
2. Trigger your CodePipeline
3. Verify the plan phase completes successfully
4. Proceed with your normal deployment workflow

---
**Note**: These changes only add read permissions and don't affect your existing infrastructure security posture.