# lambda_function.py

import os
import uuid
import json
import boto3
from datetime import datetime

s3     = boto3.client('s3')
dynamo = boto3.client('dynamodb')

def lambda_handler(event, context):
    # ——————————————
    # 1) Parse JSON payload (including contentType)
    # ——————————————
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        payload = {}

    filename    = payload.get("filename") or str(uuid.uuid4())
    account     = payload.get("account", "Individual")
    user        = payload.get("user", "anonymous@example.com")
    contentType = payload.get("contentType", "application/octet-stream")

    # ——————————————
    # 2) Generate docId
    # ——————————————
    doc_id = str(uuid.uuid4())

    # ——————————————
    # 3) Generate presigned PUT URL *with* ContentType
    # ——————————————
    bucket = os.environ["BUCKET_NAME"]
    url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket":      bucket,
            "Key":         doc_id,
            "ContentType": contentType
        },
        ExpiresIn=3600
    )

    # ——————————————
    # 4) Write metadata row to DynamoDB
    # ——————————————
    ts = datetime.utcnow().isoformat()
    dynamo.put_item(
        TableName=os.environ["METADATA_TABLE"],
        Item={
            "user":      {"S": user},
            "docId":     {"S": doc_id},
            "filename":  {"S": filename},
            "account":   {"S": account},
            "status":    {"S": "uploaded"},
            "timestamp": {"S": ts}
        }
    )

    # ——————————————
    # 5) Return JSON + CORS headers
    # ——————————————
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type":                 "application/json",
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "OPTIONS,POST,PUT",
            "Access-Control-Allow-Headers": "Content-Type,Authorization"
        },
        "body": json.dumps({
            "uploadUrl":   url,
            "docId":       doc_id,
            "filename":    filename,
            "contentType": contentType
        })
    }
