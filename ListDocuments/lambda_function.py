import os
import json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table    = dynamodb.Table(os.environ['METADATA_TABLE'])
s3       = boto3.client('s3')
BUCKET   = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    # ✅ CORS preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,GET',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization'
            },
            'body': json.dumps('CORS preflight OK')
        }

    # 1) grab query params
    params   = event.get('queryStringParameters') or {}
    user     = params.get('user')
    partner  = params.get('partner')
    category = params.get('category')

    if not user:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({ 'error': 'Missing required query param: user' })
        }

    # 2) query DynamoDB
    resp = table.query(
        KeyConditionExpression=Key('user').eq(user),
        ScanIndexForward=False
    )
    items = resp.get('Items', [])

    # 3) optional filters
    if partner:
        items = [i for i in items if i.get('partner') == partner]
    if category:
        items = [i for i in items if i.get('category') == category]

    # 4) build response
    results = []
    for i in items:
        url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={ 'Bucket': BUCKET, 'Key': i['s3Key'] },
            ExpiresIn=3600
        )
        results.append({
            'docId':       i['docId'],
            'filename':    i['filename'],
            'status':      i['status'],
            'timestamp':   i['timestamp'],
            's3Key':       i['s3Key'],
            'downloadUrl': url
        })

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(results)
    }
