import unittest
from unittest.mock import patch, MagicMock
import json
import os

# Set environment variables before importing the function
os.environ['BUCKET_NAME'] = 'test-bucket'
os.environ['METADATA_TABLE'] = 'test-table'

from getuploadurl import lambda_handler

class TestGetUploadUrl(unittest.TestCase):
    
    @patch('getuploadurl.boto3.client')
    def test_lambda_handler_success(self, mock_boto3_client):
        # Mock S3 client
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.return_value = 'https://test-presigned-url.com'
        mock_boto3_client.return_value = mock_s3
        
        # Test event
        event = {
            'body': json.dumps({
                'filename': 'test.pdf',
                'content_type': 'application/pdf'
            })
        }
        
        # Call function
        response = lambda_handler(event, {})
        
        # Assertions
        self.assertEqual(response['statusCode'], 200)
        body = json.loads(response['body'])
        self.assertIn('upload_url', body)
        self.assertEqual(body['upload_url'], 'https://test-presigned-url.com')
    
    def test_lambda_handler_missing_filename(self):
        event = {
            'body': json.dumps({
                'content_type': 'application/pdf'
            })
        }
        
        response = lambda_handler(event, {})
        
        self.assertEqual(response['statusCode'], 400)
        body = json.loads(response['body'])
        self.assertIn('error', body)

if __name__ == '__main__':
    unittest.main()