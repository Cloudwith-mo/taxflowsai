import boto3
import os
import json
from urllib.parse import unquote_plus

bedrock = boto3.client("bedrock-runtime")
ddb = boto3.client("dynamodb")

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))

    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = unquote_plus(record['s3']['object']['key'])

    # Parse S3 Key to extract partner, category, username
    key_parts = key.split('/')
    if len(key_parts) < 4:
        raise ValueError(f"Invalid key structure: {key}")

    partner, category, username, filename = key_parts[0], key_parts[1], key_parts[2], key_parts[3]

    # Reconstruct PK and SK (match your DynamoDB schema exactly)
    pk = f"user#{username}"
    sk = key  # typically the S3 object key is used as sort key (sk)

    content = f"Document uploaded: {filename}. Please generate smart tags for tax filing."

    model_id = os.environ["MODEL_ID"]
    table = os.environ["DDB_TABLE"]

    prompt = f"""
    Human: Here is a document description:\n{content}\n\nSuggest 3 relevant tags (1-3 words each).
    Assistant:
    """

    response = bedrock.invoke_model(
        modelId=model_id,
        body=json.dumps({"prompt": prompt, "max_tokens_to_sample": 100}),
        contentType="application/json",
        accept="application/json"
    )

    body = json.loads(response['body'].read())
    text = body.get("completion", "")

    tags = [t.strip().strip("#") for t in text.split(",") if t.strip()]
    print("Suggested Tags:", tags)

    # Explicitly write tags back to DynamoDB using dynamic keys
    ddb.update_item(
        TableName=table,
        Key={
            "pk": {"S": pk},
            "sk": {"S": sk}
        },
        UpdateExpression="SET tags = :tags",
        ExpressionAttributeValues={
            ":tags": {"SS": tags}
        }
    )

    return {"statusCode": 200, "tags": tags}
