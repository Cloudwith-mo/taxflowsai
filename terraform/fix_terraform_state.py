#!/usr/bin/env python3
"""
Terraform State Backend Fixer
Diagnoses and fixes the "state data in S3 does not have the expected content" error
"""

import boto3
import hashlib
import json
import sys
from botocore.exceptions import ClientError

# Configuration from backend.hcl
BUCKET_NAME = "taxflowsai-terraform-state"
STATE_KEY = "prod/terraform.tfstate"
DYNAMODB_TABLE = "terraform-state-lock"
REGION = "us-east-1"

def get_s3_object_md5(s3_client, bucket, key):
    """Get the MD5 hash of the S3 object"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read()
        md5_hash = hashlib.md5(content).hexdigest()
        return md5_hash, len(content)
    except ClientError as e:
        print(f"Error reading S3 object: {e}")
        return None, 0

def get_dynamodb_digest(dynamodb_client, table_name, state_key):
    """Get the stored digest from DynamoDB"""
    lock_id = f"{BUCKET_NAME}/{state_key}-md5"
    try:
        response = dynamodb_client.get_item(
            TableName=table_name,
            Key={'LockID': {'S': lock_id}}
        )
        if 'Item' in response:
            digest = response['Item'].get('Digest', {}).get('S', '')
            return digest, lock_id
        else:
            print(f"No digest entry found for LockID: {lock_id}")
            return None, lock_id
    except ClientError as e:
        print(f"Error reading DynamoDB: {e}")
        return None, lock_id

def delete_dynamodb_digest(dynamodb_client, table_name, lock_id):
    """Delete the digest entry from DynamoDB"""
    try:
        dynamodb_client.delete_item(
            TableName=table_name,
            Key={'LockID': {'S': lock_id}}
        )
        print(f"✅ Deleted digest entry: {lock_id}")
        return True
    except ClientError as e:
        print(f"Error deleting DynamoDB entry: {e}")
        return False

def update_dynamodb_digest(dynamodb_client, table_name, lock_id, new_digest):
    """Update the digest entry in DynamoDB"""
    try:
        dynamodb_client.put_item(
            TableName=table_name,
            Item={
                'LockID': {'S': lock_id},
                'Digest': {'S': new_digest}
            }
        )
        print(f"✅ Updated digest entry: {lock_id} -> {new_digest}")
        return True
    except ClientError as e:
        print(f"Error updating DynamoDB entry: {e}")
        return False

def main():
    print("🔍 Terraform State Backend Diagnostic Tool")
    print("=" * 50)
    
    # Initialize AWS clients
    try:
        s3_client = boto3.client('s3', region_name=REGION)
        dynamodb_client = boto3.client('dynamodb', region_name=REGION)
    except Exception as e:
        print(f"❌ Error initializing AWS clients: {e}")
        sys.exit(1)
    
    # Step 1: Get S3 object MD5
    print(f"📁 Checking S3 object: s3://{BUCKET_NAME}/{STATE_KEY}")
    s3_md5, file_size = get_s3_object_md5(s3_client, BUCKET_NAME, STATE_KEY)
    
    if not s3_md5:
        print("❌ Could not read S3 state file")
        sys.exit(1)
    
    print(f"   S3 file size: {file_size} bytes")
    print(f"   S3 MD5 hash: {s3_md5}")
    
    # Step 2: Get DynamoDB digest
    print(f"🗄️  Checking DynamoDB table: {DYNAMODB_TABLE}")
    db_digest, lock_id = get_dynamodb_digest(dynamodb_client, DYNAMODB_TABLE, STATE_KEY)
    
    if db_digest:
        print(f"   DynamoDB digest: {db_digest}")
        print(f"   Lock ID: {lock_id}")
    else:
        print("   No digest entry found in DynamoDB")
    
    # Step 3: Compare and diagnose
    print("\n🔍 Diagnosis:")
    if not db_digest:
        print("   ⚠️  Missing digest entry in DynamoDB")
        print("   This will cause Terraform to recreate the digest on next init")
    elif s3_md5 == db_digest:
        print("   ✅ S3 and DynamoDB are in sync!")
        print("   The issue might be elsewhere or already resolved")
        return
    else:
        print("   ❌ MISMATCH DETECTED!")
        print(f"   S3 MD5:      {s3_md5}")
        print(f"   DynamoDB:    {db_digest}")
        print("   This is causing the Terraform init failure")
    
    # Step 4: Offer fix options
    print("\n🛠️  Fix Options:")
    print("1. Delete the DynamoDB digest entry (Recommended)")
    print("2. Update the DynamoDB digest to match S3")
    print("3. Exit without changes")
    
    choice = input("\nSelect option (1-3): ").strip()
    
    if choice == "1":
        print("\n🗑️  Deleting DynamoDB digest entry...")
        if delete_dynamodb_digest(dynamodb_client, DYNAMODB_TABLE, lock_id):
            print("✅ Fix applied! Terraform will recreate the digest on next init.")
        else:
            print("❌ Failed to delete digest entry")
    
    elif choice == "2":
        print(f"\n📝 Updating DynamoDB digest to: {s3_md5}")
        if update_dynamodb_digest(dynamodb_client, DYNAMODB_TABLE, lock_id, s3_md5):
            print("✅ Fix applied! S3 and DynamoDB are now in sync.")
        else:
            print("❌ Failed to update digest entry")
    
    elif choice == "3":
        print("👋 Exiting without changes")
    
    else:
        print("❌ Invalid choice")
    
    print("\n🚀 Next steps:")
    print("   1. Run your CodePipeline again")
    print("   2. Or run 'terraform init' locally to test")

if __name__ == "__main__":
    main()