import unittest
from unittest.mock import patch, MagicMock
import json

from authorizer import lambda_handler

class TestAuthorizer(unittest.TestCase):
    
    def test_lambda_handler_valid_token(self):
        event = {
            'headers': {
                'authorization': 'Bearer valid-token-123'
            },
            'methodArn': 'arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/request'
        }
        
        with patch('authorizer.verify_token') as mock_verify:
            mock_verify.return_value = {'user_id': '123', 'role': 'user'}
            
            response = lambda_handler(event, {})
            
            self.assertEqual(response['principalId'], '123')
            self.assertEqual(response['policyDocument']['Statement'][0]['Effect'], 'Allow')
    
    def test_lambda_handler_invalid_token(self):
        event = {
            'headers': {
                'authorization': 'Bearer invalid-token'
            },
            'methodArn': 'arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/request'
        }
        
        with patch('authorizer.verify_token') as mock_verify:
            mock_verify.return_value = None
            
            response = lambda_handler(event, {})
            
            self.assertEqual(response['policyDocument']['Statement'][0]['Effect'], 'Deny')
    
    def test_lambda_handler_missing_token(self):
        event = {
            'headers': {},
            'methodArn': 'arn:aws:execute-api:us-east-1:123456789012:abcdef123/test/GET/request'
        }
        
        response = lambda_handler(event, {})
        
        self.assertEqual(response['policyDocument']['Statement'][0]['Effect'], 'Deny')

if __name__ == '__main__':
    unittest.main()