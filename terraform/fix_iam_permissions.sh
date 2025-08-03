#!/bin/bash

# Fix IAM Permissions for CodePipeline
# This script applies only the IAM policy changes to resolve AccessDeniedException errors

set -e

echo "🔧 Fixing IAM permissions for CodePipeline..."

# Navigate to terraform directory
cd "$(dirname "$0")"

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    echo "📦 Initializing Terraform..."
    terraform init -backend-config=backend.hcl
fi

# Target only the IAM policies that need updating
echo "🎯 Applying targeted IAM policy updates..."

terraform apply -target=aws_iam_policy.artifact_bucket_access \
                -target=aws_iam_policy.terraform_permissions \
                -auto-approve

echo "✅ IAM permissions updated successfully!"
echo ""
echo "📋 Updated policies:"
echo "   • artifact_bucket_access - Added s3:GetBucketWebsite, s3:GetBucketLocation, s3:GetBucketVersioning"
echo "   • terraform_permissions - Already includes lambda:GetPolicy and s3:GetBucketWebsite"
echo ""
echo "🚀 Your CodePipeline should now be able to run the Terraform plan phase without AccessDeniedException errors."