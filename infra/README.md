# SES Email Forwarder - Terraform Infrastructure

This directory contains Terraform configuration to deploy the SES Email Forwarder Lambda function with all necessary IAM roles and CloudWatch logging.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Node.js 22+ and npm (for installing Lambda dependencies)
- An S3 bucket for SES to store incoming emails

## What This Terraform Creates

1. **Lambda Function** - The email forwarding function with Node.js 22 runtime
2. **IAM Role** - Execution role for the Lambda function
3. **IAM Policies**:
   - CloudWatch Logs access for logging
   - S3 GetObject access to read emails from the SES bucket
   - SES SendRawEmail access to forward emails
4. **CloudWatch Log Group** - For Lambda function logs with configurable retention
5. **Lambda Permission** - Allows SES to invoke the Lambda function

## Setup Instructions

### 1. Install Lambda Dependencies

Before deploying with Terraform, install the Lambda function dependencies:

```bash
cd ..
npm install
cd infra
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region       = "us-east-1"
function_name    = "SESEmailForwarder"
forward_to_email = "your-email@example.com"
ses_email_bucket = "your-ses-email-bucket"
environment      = "prod"
```

**Required Variables:**
- `forward_to_email` - The email address to forward all emails to
- `ses_email_bucket` - The S3 bucket where SES stores incoming emails

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

Review the resources that will be created.

### 5. Deploy

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 6. Note the Outputs

After deployment, Terraform will output important values:

```bash
terraform output
```

Save the `lambda_function_invoke_arn` - you'll need this when configuring SES receipt rules.

## Updating the Lambda Function

After making changes to the Lambda code:

1. Ensure dependencies are up to date:
   ```bash
   cd .. && npm install && cd infra
   ```

2. Re-apply Terraform:
   ```bash
   terraform apply
   ```

Terraform will detect the code changes and update the Lambda function.

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for deployment | `us-east-1` | No |
| `function_name` | Lambda function name | `SESEmailForwarder` | No |
| `environment` | Environment name | `prod` | No |
| `forward_to_email` | Destination email address | - | **Yes** |
| `ses_email_bucket` | S3 bucket for SES emails | - | **Yes** |
| `lambda_timeout` | Function timeout in seconds | `30` | No |
| `lambda_memory_size` | Memory allocation in MB | `256` | No |
| `log_retention_days` | CloudWatch log retention | `14` | No |
| `default_tags` | Tags for all resources | See `variables.tf` | No |

## Outputs

| Output | Description |
|--------|-------------|
| `lambda_function_arn` | Full ARN of the Lambda function |
| `lambda_function_name` | Name of the Lambda function |
| `lambda_function_invoke_arn` | Invoke ARN (use in SES receipt rules) |
| `lambda_execution_role_arn` | ARN of the IAM execution role |
| `cloudwatch_log_group_name` | CloudWatch log group name |
| `aws_account_id` | Your AWS account ID |

## Post-Deployment: Configure SES

After Terraform deployment, you need to manually configure SES (not included in Terraform):

### 1. Create or Verify S3 Bucket

Ensure the S3 bucket specified in `ses_email_bucket` exists and has proper permissions for SES:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::your-ses-email-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceAccount": "YOUR_ACCOUNT_ID"
        }
      }
    }
  ]
}
```

### 2. Configure SES Receipt Rule

1. Go to AWS SES Console > Email Receiving > Rule Sets
2. Create or select a rule set
3. Add a new rule with:
   - **Recipients**: The email addresses to forward (e.g., `incoming@yourdomain.com`)
   - **Actions**:
     - First: **S3 Action** - Save to your S3 bucket
     - Second: **Lambda Action** - Select your Lambda function

### 3. Verify Email Addresses

If your SES is in sandbox mode, verify:
- The receiving domain/email
- The `forward_to_email` address

## Monitoring

### View Logs

```bash
aws logs tail /aws/lambda/SESEmailForwarder --follow
```

Or use the AWS Console:
1. Go to CloudWatch > Log Groups
2. Find `/aws/lambda/SESEmailForwarder`
3. View log streams

### Check Lambda Metrics

```bash
# View invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=SESEmailForwarder \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# View errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=SESEmailForwarder \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Troubleshooting

### Permission Errors

If you see permission errors in CloudWatch Logs:

1. Verify the IAM role has the correct policies attached:
   ```bash
   terraform output lambda_execution_role_name
   aws iam list-attached-role-policies --role-name <role-name>
   ```

2. Check S3 bucket permissions allow the Lambda role to GetObject

3. Verify SES has permission to invoke the Lambda:
   ```bash
   aws lambda get-policy --function-name SESEmailForwarder
   ```

### Email Not Forwarding

1. Check CloudWatch Logs for errors
2. Verify the SES receipt rule is active
3. Ensure the S3 bucket allows SES to write objects
4. Verify `forward_to_email` is correct in Lambda environment variables

### Update Environment Variables

To update the forwarding email address:

1. Edit `terraform.tfvars`
2. Run `terraform apply`

Or use AWS CLI:
```bash
aws lambda update-function-configuration \
  --function-name SESEmailForwarder \
  --environment Variables="{FORWARD_TO_EMAIL=newemail@example.com}"
```

## Cost Considerations

- **Lambda**: Free tier includes 1M requests/month and 400,000 GB-seconds compute
- **CloudWatch Logs**: $0.50 per GB ingested (beyond free tier)
- **S3**: Storage costs for emails (minimal)
- **SES**: $0.10 per 1,000 emails received (after free tier)

With typical usage, this should stay within free tier limits.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: This will not delete:
- The S3 bucket (if it has objects)
- SES receipt rules
- Emails stored in S3

## State Management

This configuration uses local state. For production use, consider:

1. **Remote State** with S3 backend:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-terraform-state-bucket"
       key    = "ses-forwarder/terraform.tfstate"
       region = "us-east-1"
     }
   }
   ```

2. **State Locking** with DynamoDB for team collaboration

## Security Best Practices

- Store `terraform.tfvars` securely (it's excluded via `.gitignore`)
- Use AWS Secrets Manager for sensitive values in production
- Enable MFA for AWS accounts with deployment permissions
- Review IAM policies regularly
- Enable CloudTrail for audit logging
- Use VPC endpoints if Lambda needs to be in a VPC

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS SES Email Receiving](https://docs.aws.amazon.com/ses/latest/dg/receiving-email.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
