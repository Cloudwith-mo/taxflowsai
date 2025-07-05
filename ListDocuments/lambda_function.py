import json
import os
import boto3
from collections import defaultdict
from boto3.dynamodb.conditions import Key

# AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

# Constants
BUCKET = os.environ.get('BUCKET_NAME', 'taxflowsai-uploads')
TABLE_NAME = os.environ.get('TABLE_NAME', 'TaxFlowsAI_Metadata')
DEFAULT_CATEGORY = "Individual"
DEFAULT_FILENAME = "Untitled.pdf"
table = dynamodb.Table(TABLE_NAME)


def cors_headers():
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization'
    }


def lambda_handler(event, context):
    print("📍 Lambda started")

    # CORS preflight
    if event.get("httpMethod") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": cors_headers(),
            "body": json.dumps("CORS OK")
        }

    params = event.get('queryStringParameters') or {}
    partner = params.get('partner')
    category = params.get('category', DEFAULT_CATEGORY)
    name_filter = params.get('name', '').lower()

    if not partner:
        return {
            'statusCode': 400,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Missing required query param: partner'})
        }

    print("🔍 Querying GSI with:", {"partner": partner, "category": category})

    # Paginated query
    items = []
    exclusive_start_key = None
    while True:
        kwargs = {
            'IndexName': 'PartnerCategoryIndex',
            'KeyConditionExpression': Key('partner').eq(partner) & Key('category').eq(category)
        }
        if exclusive_start_key:
            kwargs['ExclusiveStartKey'] = exclusive_start_key

        try:
            response = table.query(**kwargs)
        except Exception as e:
            print("❌ DynamoDB error:", e)
            return {
                'statusCode': 500,
                'headers': cors_headers(),
                'body': json.dumps({'error': str(e)})
            }

        page_items = response.get('Items', [])

        if name_filter:
            page_items = [i for i in page_items if name_filter in (i.get('user') or '').lower()]

        items.extend(page_items)
        exclusive_start_key = response.get('LastEvaluatedKey')
        if not exclusive_start_key:
            break

    print(f"✅ Retrieved {len(items)} items")

    # Group results
    grouped = defaultdict(lambda: {'docs': []})
    for i in items:
        user_key = i.get('user')
        if not user_key:
            print(f"⚠️ Skipping item with no user: {i}")
            continue

        filename = i.get('filename', DEFAULT_FILENAME)
        s3_key = i.get('s3Key')

        if not isinstance(s3_key, str) or not s3_key.strip():
            print(f"⚠️ Skipping item with bad s3Key: {i}")
            continue

        try:
            presigned_url = s3.generate_presigned_url(
                ClientMethod='get_object',
                Params={'Bucket': BUCKET, 'Key': s3_key},
                ExpiresIn=3600
            )
        except Exception as e:
            print(f"⚠️ Error generating URL for {s3_key}: {e}")
            continue

        grouped[user_key].update({
            'name': user_key,
            'partner': i.get('partner'),
            'category': i.get('category'),
            'avatar': f"https://i.pravatar.cc/150?u={i.get('docId')}"
        })

        grouped[user_key]['docs'].append({
            'name': filename,
            'desc': filename.replace('_', ' ').replace('.pdf', ''),
            'status': i.get('status', 'incomplete'),
            'url': presigned_url,
            'comment': i.get('comment', '')
        })

    print(f"📤 Returning {len(grouped)} grouped clients")

    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps(list(grouped.values()))
    }
