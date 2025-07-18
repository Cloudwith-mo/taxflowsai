import os
import uuid
import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')
dynamo = boto3.client('dynamodb')

CORS_HEADERS = {
    'Access-Control-Allow-Origin': 'https://taxflowsai.com',
    'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT,GET',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
}

def lambda_handler(event, context):
    # Handle CORS preflight requests
    if event.get('httpMethod', '') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': CORS_HEADERS,
            'body': json.dumps('CORS preflight OK')
        }

    try:
        print("Event received:", json.dumps(event))  # Log the full event for debugging
        
        payload = json.loads(event.get("body", "{}"))

        print("Payload parsed:", payload)  # Log parsed payload
        
        doc_id = str(uuid.uuid4())
        filename = payload.get("filename", f"document-{doc_id}.pdf").replace("/", "_").strip()
        account = payload.get("account", "Individual")
        contentType = payload.get("contentType", "application/octet-stream")
        user = payload.get("user", "").strip()
        username = payload.get("username", "").strip()

        if not user:
            raise ValueError("Missing or invalid 'user' email")

        partner = payload.get("partner", "AXY Tax Office").strip()
        category = payload.get("category", "Individual").strip()

        folder_prefix = "/".join([p.replace("/", "_") for p in [partner, category, username] if p.strip()])
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

        item = {
            "user": {"S": user},
            "docId": {"S": doc_id},
            "filename": {"S": filename},
            "account": {"S": account},
            "partner": {"S": partner},
            "category": {"S": category},
            "status": {"S": "uploaded"},
            "timestamp": {"S": ts},
            "s3Key": {"S": key}
        }

        tags = payload.get("tags", [])
        if tags:
            item["tags"] = {"SS": list(set(tags))}

        dynamo.put_item(TableName=os.environ["METADATA_TABLE"], Item=item)

        response_body = {
            "uploadUrl": put_url,
            "downloadUrl": get_url,
            "docId": doc_id,
            "filename": filename,
            "contentType": contentType
        }

        print("Successful response:", response_body)

        return {
    'statusCode': 200,
    'headers': {
        "Access-Control-Allow-Origin": "https://taxflowsai.com",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,GET,POST,PUT",
        "Access-Control-Allow-Credentials": "true"  # important
    },
    'body': json.dumps(response_body)
}

    except Exception as e:
        print("❌ Lambda runtime error:", str(e))
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({"error": str(e)})
        }
