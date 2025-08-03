# TaxFlowsAI Architecture Documentation

## Overview
TaxFlowsAI is a serverless document processing platform built on AWS, following microservices architecture with Infrastructure as Code (IaC) principles.

## Architecture Components

### 1. Frontend Layer
- **Technology**: Static HTML/JS hosted on GitHub Pages
- **Domain**: taxflowsai.com
- **Features**: Client dashboard, admin dashboard, authentication

### 2. API Layer
- **Service**: AWS API Gateway (HTTP API)
- **Authentication**: Custom Lambda authorizer
- **Rate Limiting**: 1000 requests/second, 2000 burst
- **CORS**: Configured for taxflowsai.com

### 3. Compute Layer
- **Service**: AWS Lambda Functions
- **Runtime**: Python 3.12
- **Shared Dependencies**: Lambda Layer (reduces cold starts)
- **Functions**:
  - `get-upload-url`: Generate S3 presigned URLs
  - `list-documents`: Retrieve document metadata
  - `authorizer`: API authentication
  - `patch-metadata`: Update document metadata
  - `tag-generator`: AI-powered document tagging (Bedrock)
  - `set-admin-category`: Admin document categorization

### 4. Storage Layer
- **Documents**: S3 bucket (taxflowsai-uploads)
- **Metadata**: DynamoDB table (TaxFlowsAI_Metadata)
- **State**: S3 + DynamoDB for Terraform state

### 5. AI/ML Layer
- **Service**: Amazon Bedrock
- **Model**: Claude 3 Sonnet
- **Purpose**: Document analysis and tagging

## Security Model

### IAM Policies
- **Principle**: Least privilege access
- **Lambda Execution Role**: Custom policies for specific resources
- **No FullAccess Policies**: All permissions are resource-specific

### API Security
- **Authentication**: Lambda authorizer with JWT tokens
- **Rate Limiting**: API Gateway throttling
- **CORS**: Restricted to production domain

## Infrastructure as Code

### Structure
```
infrastructure/
├── modules/           # Reusable Terraform modules
│   ├── iam/          # IAM roles and policies
│   ├── lambda/       # Lambda functions and layers
│   └── api-gateway/  # API Gateway configuration
└── environments/     # Environment-specific configs
    ├── dev/
    ├── staging/
    └── prod/
```

### Deployment Pipeline
1. **Source**: GitHub repository
2. **Build**: CodeBuild (Terraform plan)
3. **Security**: tfsec scanning
4. **Approval**: Manual approval gate
5. **Deploy**: CodeBuild (Terraform apply)

## Monitoring & Observability

### Logging
- **CloudWatch Logs**: All Lambda functions
- **Log Level**: Environment-specific (ERROR in prod)

### Metrics
- **API Gateway**: Request count, latency, errors
- **Lambda**: Duration, memory usage, errors
- **DynamoDB**: Read/write capacity, throttling

## Disaster Recovery

### Backup Strategy
- **DynamoDB**: Point-in-time recovery enabled
- **S3**: Versioning enabled
- **Terraform State**: S3 versioning + DynamoDB locking

### Recovery Procedures
- **RTO**: 4 hours (manual intervention)
- **RPO**: 1 hour (DynamoDB PITR)

## Cost Optimization

### Serverless Benefits
- **Pay-per-use**: No idle server costs
- **Auto-scaling**: Handles traffic spikes automatically
- **Shared Layer**: Reduces Lambda package sizes

### Resource Optimization
- **DynamoDB**: On-demand billing
- **Lambda**: Right-sized memory allocation
- **S3**: Lifecycle policies for old documents