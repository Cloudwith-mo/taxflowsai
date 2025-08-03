#!/bin/bash
# Build shared Lambda layer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building shared Lambda layer..."

# Create temporary directory
rm -rf temp_layer
mkdir -p temp_layer/python

# Install dependencies
pip install -r requirements.txt -t temp_layer/python/

# Create zip file
cd temp_layer
zip -r ../layer.zip .
cd ..

# Cleanup
rm -rf temp_layer

echo "✅ Shared layer built: layer.zip"