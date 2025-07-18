import json
import os
import boto3
from collections import defaultdict
from boto3.dynamodb.conditions import Key
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

BUCKET = os.environ.get('BUCKET_NAME', 'taxflowsai-uploads')
TABLE_NAME = os.environ.get('TABLE_NAME', 'TaxFlowsAI_Metadata')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    try:
        params = event.get('queryStringParameters') or {}
        partner = params.get('partner')
        category = params.get('category', 'Individual')
        name_filter = params.get('name', '').lower()

        if not partner:
            raise ValueError('Missing required query param: partner')

        items = []
        last_evaluated_key = None

        while True:
            query_kwargs = {
                'IndexName': 'PartnerCategoryIndex',
                'KeyConditionExpression': Key('partner').eq(partner) & Key('category').eq(category)
            }
            if last_evaluated_key:
                query_kwargs['ExclusiveStartKey'] = last_evaluated_key

            response = table.query(**query_kwargs)
            page_items = response.get('Items', [])
            if name_filter:
                page_items = [i for i in page_items if name_filter in (i.get('user') or '').lower()]
            items.extend(page_items)

            last_evaluated_key = response.get('LastEvaluatedKey')
            if not last_evaluated_key:
                break

        grouped = defaultdict(lambda: {'docs': []})

        for i in items:
            user_key = i.get('user')
            if not user_key:
                continue

            s3_key = i.get('s3Key')
            if not isinstance(s3_key, str) or not s3_key.strip():
                continue

            presigned_url = s3.generate_presigned_url(
                ClientMethod='get_object',
                Params={'Bucket': BUCKET, 'Key': s3_key},
                ExpiresIn=3600
            )

            filename = i.get('filename', 'Untitled.pdf')
            timestamp = i.get('timestamp', datetime.utcnow().isoformat())

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
                'comment': i.get('comment', ''),
                'timestamp': timestamp
            })

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': 'https://taxflowsai.com',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT,GET',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps(list(grouped.values()))
        }

    except Exception as e:
        print("❌ Lambda runtime error:", str(e))
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': 'https://taxflowsai.com',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT,GET',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps({"error": str(e)})
        }
