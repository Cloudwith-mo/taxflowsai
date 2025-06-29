import os
import uuid
import json
import boto3
from datetime import datetime

# clients
s3     = boto3.client('s3')
dynamo = boto3.client('dynamodb')

def lambda_handler(event, context):
    # 1) parse payload
    payload = json.loads(event.get("body", "{}"))

    filename    = payload.get("filename", str(uuid.uuid4()))
    account     = payload.get("account", "Individual")
    user        = payload.get("user", "anonymous")
    contentType = payload.get("contentType", "application/octet-stream")

    # 2) build a safe folder prefix out of partner/category/username
    raw_parts = [
        payload.get("partner", ""), 
        payload.get("category", ""), 
        payload.get("username", "")
    ]
    parts = [p.replace("/", "_").strip() for p in raw_parts if p.strip()]
    folder_prefix = "/".join(parts)

    # 3) generate a unique key (with or without prefix)
    doc_id = str(uuid.uuid4())
    key = f"{folder_prefix}/{doc_id}" if folder_prefix else doc_id

    bucket = os.environ["BUCKET_NAME"]

    # 4) presigned PUT URL
    put_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket":      bucket,
            "Key":         key,
            "ContentType": contentType
        },
        ExpiresIn=3600
    )

    # 5) presigned GET URL
    get_url = s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": bucket,
            "Key":    key
        },
        ExpiresIn=3600
    )

    # 6) write metadata to DynamoDB, **including** partner & category
    ts = datetime.utcnow().isoformat()
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
            "s3Key":     {"S": key}
        }
    )

    # 7) return URLs and IDs
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

    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps('CORS preflight OK')
        }
