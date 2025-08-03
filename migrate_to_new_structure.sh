#!/bin/bash
# Migration script to new architecture structure

set -e

echo "🚀 Migrating TaxFlowsAI to new architecture structure..."

# Build shared Lambda layer
echo "📦 Building shared Lambda layer..."
cd src/lambda/shared
./build_layer.sh
cd ../../..

# Create Lambda function packages (without dependencies)
echo "📦 Creating Lambda function packages..."

functions=("get-upload-url" "list-documents" "authorizer" "patch-metadata" "tag-generator" "set-admin-category")

for func in "${functions[@]}"; do
    echo "  Building $func..."
    cd "src/lambda/$func"
    zip -r function.zip *.py 2>/dev/null || echo "    No Python files found for $func"
    cd ../../..
done

# Copy backend configuration
echo "📋 Setting up Terraform backend..."
cp terraform/backend.hcl infrastructure/environments/prod/

# Copy terraform.tfvars if it exists
if [ -f terraform/terraform.tfvars ]; then
    cp terraform/terraform.tfvars infrastructure/environments/prod/
    echo "  ✅ Copied terraform.tfvars"
fi

echo "✅ Migration complete!"
echo ""
echo "Next steps:"
echo "1. Update your CI/CD pipeline to use infrastructure/environments/prod/"
echo "2. Test the new structure: cd infrastructure/environments/prod && terraform plan"
echo "3. Remove old terraform/ directory after successful deployment"