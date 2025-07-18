import json
from jose import jwk, jwt
from jose.utils import base64url_decode
import urllib.request

USERPOOL_ID = 'us-east-1_WSlbBY4sQ'
APP_CLIENT_ID = '7vkumiq86lap5de5195f6llkaa'
REGION = 'us-east-1'

keys_url = f'https://cognito-idp.{REGION}.amazonaws.com/{USERPOOL_ID}/.well-known/jwks.json'
with urllib.request.urlopen(keys_url) as f:
    response = f.read()
keys = json.loads(response.decode('utf-8'))['keys']

# exactly "lambda_handler"
def lambda_handler(event, context):
    token = event['headers'].get('authorization', '').replace('Bearer ', '')
    
    try:
        headers = jwt.get_unverified_headers(token)
        kid = headers['kid']
        key_index = next((i for i, k in enumerate(keys) if k['kid'] == kid), -1)
        if key_index == -1:
            raise Exception('Public key not found in jwks.json')
        
        public_key = jwk.construct(keys[key_index])
        message, encoded_signature = token.rsplit('.', 1)
        decoded_signature = base64url_decode(encoded_signature.encode('utf-8'))
        
        if not public_key.verify(message.encode("utf8"), decoded_signature):
            raise Exception('Signature verification failed')

        claims = jwt.get_unverified_claims(token)
        if claims['aud'] != APP_CLIENT_ID:
            raise Exception('Token was not issued for this audience')
        
        return generate_policy(claims['sub'], 'Allow', event['routeArn'])
    
    except Exception as e:
        print(e)
        return generate_policy('user', 'Deny', event['routeArn'])

def generate_policy(principalId, effect, resource):
    return {
        'principalId': principalId,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
    }
