import os, uuid, boto3, json

s3      = boto3.client('s3')
dynamo  = boto3.client('dynamodb')

def lambda_handler(event, context):
    bucket = os.environ['BUCKET_NAME']
    table  = os.environ['METADATA_TABLE']

    # Generate a unique docId
    doc_id = str(uuid.uuid4())

    # Create a presigned URL
    url = s3.generate_presigned_url(
        'put_object',
        Params={'Bucket': bucket, 'Key': doc_id},
        ExpiresIn=300
    )

    # Write metadata to DynamoDB
    dynamo.put_item(
        TableName=table,
        Item={
          'user':   {'S': event['requestContext']['authorizer']['jwt']['claims']['email']},
          'docId':  {'S': doc_id},
          'status': {'S': 'uploaded'},
          'ts':     {'N': str(int(context.aws_request_id.split('-')[0],16))}
        }
    )

    return {
      'statusCode': 200,
      'headers': {'Content-Type':'application/json'},
      'body': json.dumps({'uploadUrl': url, 'docId': doc_id})
    }
