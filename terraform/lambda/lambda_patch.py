import json
import boto3
from datetime import datetime

dynamo = boto3.client('dynamodb')
table_name = 'TaxFlowsAI_Metadata'

DEFAULT_PARTNER = "AXY Tax Office"
DEFAULT_CATEGORY = "Individual"
DEFAULT_ACCOUNT = "Individual"

def lambda_handler(event, context):
    try:
        paginator = dynamo.get_paginator('scan')
        pages = paginator.paginate(TableName=table_name)

        count = 0
        patched_docs = []

        for page in pages:
            for item in page.get('Items', []):
                user = item.get('user', {}).get('S')
                doc_id = item.get('docId', {}).get('S')

                if not user or not doc_id:
                    print(f"⚠️ Skipped item with missing user/docId: {item}")
                    continue

                partner_val = item.get('partner', {}).get('S', '').strip()
                category_val = item.get('category', {}).get('S', '').strip()
                account_val = item.get('account', {}).get('S', '').strip()
                filename_val = item.get('filename', {}).get('S', '').strip()
                ts_val = item.get('timestamp', {}).get('S', '').strip()

                partner = partner_val or DEFAULT_PARTNER
                category = category_val or DEFAULT_CATEGORY
                account = account_val or DEFAULT_ACCOUNT
                filename = filename_val or f"document-{doc_id}.pdf"
                timestamp = ts_val or datetime.utcnow().isoformat()
                username = user.split("@")[0].replace("/", "_")
                s3key = f"{partner.replace('/', '_')}/{category.replace('/', '_')}/{username}/{filename}"

                updated_item = {
                    'user': {'S': user},
                    'docId': {'S': doc_id},
                    'partner': {'S': partner},
                    'category': {'S': category},
                    'account': {'S': account},
                    'filename': {'S': filename},
                    'timestamp': {'S': timestamp},
                    'status': item.get('status', {'S': 'uploaded'}),
                    's3Key': {'S': s3key}
                }

                if 'tags' in item:
                    updated_item['tags'] = item['tags']

                dynamo.put_item(TableName=table_name, Item=updated_item)
                count += 1
                patched_docs.append(f"{user} / {doc_id}")

        print(f"✅ Patched {count} documents.")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': 'https://taxflowsai.com',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,PUT,GET',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps({
                'message': f'✅ Patched {count} items.',
                'patched': patched_docs[:10]
            })
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
