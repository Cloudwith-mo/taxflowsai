import os
import uuid
import json
import boto3
from datetime import datetime

s3     = boto3.client('s3')
dynamo = boto3.client('dynamodb')

def lambda_handler(event, context):
    print("📍 Lambda started")


def lambda_handler(event, context):
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

    payload = json.loads(event.get("body", "{}"))

    doc_id      = str(uuid.uuid4())
    filename    = payload.get("filename", f"document-{doc_id}.pdf").replace("/", "_").strip()
    account     = payload.get("account", "Individual")
    contentType = payload.get("contentType", "application/octet-stream")
    user        = str(payload.get("user", "")).strip()
    username    = str(payload.get("username", "")).strip()

    if not user:
        raise ValueError("Missing or invalid 'user' email")

    # Fallback-safe defaults
    partner  = payload.get("partner", "").strip() or "AXY Tax Office"
    category = payload.get("category", "").strip() or "Individual"

    # Build folder structure
    folder_parts = [partner, category, username]
    folder_prefix = "/".join([p.replace("/", "_") for p in folder_parts if p.strip()])
    key = f"{folder_prefix}/{filename}" if folder_prefix else filename

    bucket = os.environ["BUCKET_NAME"]
    ts = datetime.utcnow().isoformat()

    put_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": bucket, "Key": key, "ContentType": contentType},
        ExpiresIn=3600
    )

    get_url = s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=3600
    )

    print("📥 Payload received:", json.dumps(payload))
    print(f"📦 Uploading metadata for user: {user} | filename: {filename}")

    item = {
        "user":      {"S": user},
        "docId":     {"S": doc_id},
        "filename":  {"S": filename},
        "account":   {"S": account},
        "partner":   {"S": partner},
        "category":  {"S": category},
        "status":    {"S": "uploaded"},
        "timestamp": {"S": ts},
        "s3Key":     {"S": key}
    }

    tags = payload.get("tags", [])
    if tags:
        item["tags"] = {"SS": list(set(tags))}

    dynamo.put_item(
        TableName=os.environ["METADATA_TABLE"],
        Item=item
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
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
