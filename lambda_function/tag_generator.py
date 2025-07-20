import boto3
import os
import json

bedrock = boto3.client("bedrock-runtime")
ddb = boto3.client("dynamodb")

def lambda_handler(event, context):
    print("EVENT:", json.dumps(event))
    
    # Extract info from S3 event
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key = record['s3']['object']['key']
    
    # Mock document content (in real app, pull from S3 or embed text)
    content = f"Document uploaded: {key}. Please generate smart tags for tax filing."

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

    # Save tags to DynamoDB (assumes partition key: user#account + docId)
    ddb.update_item(
        TableName=table,
        Key={
            "pk": {"S": "user#test@example.com"},  # 🔁 TODO: Dynamically pass in real keys
            "sk": {"S": key}
        },
        UpdateExpression="SET tags = :tags",
        ExpressionAttributeValues={
            ":tags": {"SS": tags}
        }
    )

    return {"statusCode": 200, "tags": tags}
cd 