# TaxFlowsAI Monitoring & Observability

## CloudWatch Dashboard
- **Location**: AWS Console → CloudWatch → Dashboards → `taxflowsai-prod-dashboard`
- **Metrics Tracked**:
  - API Gateway: Request count, latency, 4XX/5XX errors
  - Lambda: Duration, errors, memory usage
  - DynamoDB: Read/write capacity, throttling

## Alerting
- **SNS Topic**: `taxflowsai-prod-alerts`
- **Triggers**:
  - API Gateway 5XX errors > 10 in 10 minutes
  - Lambda function errors > 5 in 10 minutes
  - DynamoDB throttling events

## X-Ray Tracing
- **Service Map**: Visual representation of request flow
- **Trace Analysis**: End-to-end request tracing
- **Performance Insights**: Identify bottlenecks

## Log Management
- **Retention**: 30 days for production
- **Structured Logging**: JSON format with correlation IDs
- **Log Groups**: `/aws/lambda/{function-name}`

## Security Monitoring
- **GuardDuty**: Threat detection and monitoring
- **Config Rules**: Compliance monitoring
- **CloudTrail**: API call auditing