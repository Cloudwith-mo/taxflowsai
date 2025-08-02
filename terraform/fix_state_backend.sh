#!/bin/bash
# Quick fix for Terraform state backend digest mismatch
# This script deletes the problematic DynamoDB digest entry

set -e

BUCKET_NAME="taxflowsai-terraform-state"
STATE_KEY="prod/terraform.tfstate"
DYNAMODB_TABLE="terraform-state-lock"
REGION="us-east-1"
LOCK_ID="${BUCKET_NAME}/${STATE_KEY}-md5"

echo "🔧 Terraform State Backend Quick Fix"
echo "=================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

echo "🗑️  Deleting DynamoDB digest entry: $LOCK_ID"

# Delete the digest entry from DynamoDB
aws dynamodb delete-item \
    --region "$REGION" \
    --table-name "$DYNAMODB_TABLE" \
    --key '{"LockID":{"S":"'$LOCK_ID'"}}' \
    --no-cli-pager

if [ $? -eq 0 ]; then
    echo "✅ Successfully deleted digest entry"
    echo "🚀 You can now run terraform init again"
else
    echo "❌ Failed to delete digest entry"
    exit 1
fi