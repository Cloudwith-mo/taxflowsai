import os
import uuid
import json
import boto3
from datetime import datetime

# AWS clients
s3     = boto3.client('s3')
dynamo = boto3.client('dynamodb')

def lambda_handler(event, context):
    # ✅ Handle CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps('CORS preflight OK')
        }

    # ✅ Parse incoming payload
    payload = json.loads(event.get("body", "{}"))
    
    filename    = payload.get("filename", str(uuid.uuid4())).replace("/", "_").strip()
    account     = payload.get("account", "Individual")
    contentType = payload.get("contentType", "application/octet-stream")
    
    # ✅ Ensure user is a clean string
    user = str(payload.get("user", "")).strip()
    if not user:
        raise ValueError("Missing or invalid 'user' email")
    
    # ✅ Build S3 folder path from partner/category/username
    raw_parts = [
        payload.get("partner", ""), 
        payload.get("category", ""), 
        payload.get("username", "")
    ]
    parts = [p.replace("/", "_").strip() for p in raw_parts if p.strip()]
    folder_prefix = "/".join(parts)

    # ✅ Build S3 object key using filename
    doc_id = str(uuid.uuid4())
    key = f"{folder_prefix}/{filename}" if folder_prefix else filename

    # ✅ S3 bucket name from env
    bucket = os.environ["BUCKET_NAME"]

    # ✅ Generate presigned PUT URL
    put_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": bucket,
            "Key": key,
            "ContentType": contentType
        },
        ExpiresIn=3600
    )

    # ✅ Generate presigned GET URL
    get_url = s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": bucket,
            "Key": key
        },
        ExpiresIn=3600
    )

    # ✅ Write metadata to DynamoDB
    ts = datetime.utcnow().isoformat()
    print("📥 Payload received:", json.dumps(payload))
    print(f"📦 Uploading metadata for user: {user} | filename: {filename}")

    dynamo.put_item(
        TableName=os.environ["METADATA_TABLE"],
        Item={
            "user":      {"S": user},
            "docId":     {"S": doc_id},
            "filename":  {"S": filename},
            "account":   {"S": account},
            "partner":   {"S": payload.get("partner", "")},
            "category":  {"S": payload.get("category", "")},
            "status":    {"S": "uploaded"},
            "timestamp": {"S": ts},
            "s3Key":     {"S": key},
            "tags":      {"SS": payload.get("tags", [])}
        }
    )

    # ✅ Return everything to client
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type":                 "application/json",
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "OPTIONS,POST,PUT",
            "Access-Control-Allow-Headers": "Content-Type,Authorization"
        },
        "body": json.dumps({
            "uploadUrl":   put_url,
            "downloadUrl": get_url,
            "docId":       doc_id,
            "filename":    filename,
            "contentType": contentType
        })
    }
