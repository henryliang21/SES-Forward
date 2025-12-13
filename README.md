# SES Email Forwarder

An AWS Lambda function that forwards emails received via Amazon SES to a designated email address.

## Features

- Forwards emails received by SES to a specified email address
- Preserves original email content and formatting
- Adds forwarding information in email headers
- Sets Reply-To to the original sender for easy responses
- Stores original recipient information in X-headers

## Prerequisites

- An AWS account with SES email receiving configured (domain/email identity verified)
- An S3 bucket where SES stores incoming emails
- A receipt rule set that stores emails to S3 (you will add the Lambda action after deployment)
- Node.js 22+ (for packaging the Lambda code)
- Terraform >= 1.0 (to deploy the Lambda/IAM resources in `./infra`)
- AWS CLI configured with credentials that can deploy the Terraform resources

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure AWS SES

#### Verify Domain/Email Address

Verify the domain or email address you want to forward to in the SES console.

#### Create S3 Bucket

Create an S3 bucket to store incoming emails:

```bash
aws s3 mb s3://your-ses-email-bucket
```

#### Create SES Receipt Rule

1. Go to SES Console > Email Receiving > Rule Sets
2. Create a new rule set or use an existing one
3. Add a rule with:
   - Recipients: The email addresses you want to forward (e.g., `incoming@yourdomain.com`)
   - Actions:
     - First action: S3 - Store to your S3 bucket
       - Optional: set an S3 object key prefix (for example, `emails/`)
     - Second action: Lambda - Add this after you deploy the function in the next section
       - If you configured an S3 object key prefix above, set `ses_s3_prefix` in Terraform to the same value

### 3. Deploy Lambda Function

This repository includes Terraform in `./infra` to deploy the Lambda function, IAM role/policies, CloudWatch log group, and the SES invoke permission. It does not create the S3 bucket or SES receipt rules.

#### Install and Configure AWS CLI

1. Install the AWS CLI: (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)<https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>
2. Configure credentials, default region, and output format:
```bash
aws configure
```

#### Configure Terraform variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `infra/terraform.tfvars` and set at least:

- `forward_to_email` (required)
- `ses_email_bucket` (required)
- `ses_s3_prefix` (optional; must match the S3 action prefix in your SES receipt rule, if used)

#### Initialize Terraform

```bash
terraform init
```

#### Review the plan

```bash
terraform plan
```

#### Apply

```bash
terraform apply
```

### 4. Configure SES to Invoke Lambda

1. Go to SES Console > Email Receiving > Rule Sets
2. Edit the rule set created earlier
3. Edit the rule:
   - Recipients: The email addresses you want to forward (e.g., `incoming@yourdomain.com`)
   - Actions:
     - Add the action: Lambda - invoke the function created by Terraform (defaults to `SESEmailForwarder`)

You can also retrieve the deployed function name from Terraform:

```bash
cd infra
terraform output lambda_function_name
```

## Environment Variables

These are configured on the Lambda function by Terraform (see `./infra/lambda.tf`):

- `FORWARD_TO_EMAIL` (required): The email address to forward all received emails to
- `S3_BUCKET` (required): The S3 bucket where the received emails are stored
- `S3_PREFIX` (optional): The prefix prepended to the SES message ID when reading from S3 (must match the SES receipt rule’s S3 key prefix, if set)

## How It Works

1. SES receives an email
2. SES stores the email in the S3 bucket
3. SES triggers the Lambda function
4. Lambda retrieves the email from S3
5. Lambda modifies the email headers:
   - Sets `To:` to the forwarding address
   - Sets `Reply-To:` to the original sender
   - Adds `X-Original-To:` with original recipients
   - Adds `X-Forwarded-By:` header
6. Lambda sends the modified email via SES

## Testing

Send a test email to your configured SES receiving address. Check CloudWatch Logs for the Lambda function to debug any issues.

## Monitoring

Monitor the Lambda function via:

- CloudWatch Logs: `/aws/lambda/SESEmailForwarder`
- CloudWatch Metrics: Invocations, Errors, Duration
- SES sending statistics in the SES console

## Troubleshooting

### Email not forwarded

- Check CloudWatch Logs for errors
- Verify SES receipt rule is active
- Ensure S3 bucket permissions allow SES to write
- Verify FORWARD_TO_EMAIL environment variable is set
- Check that the forwarding email address is verified in SES (if in sandbox mode)

### Permission errors

- Verify IAM role has required permissions
- Check Lambda execution role is attached to the function
- Ensure SES has permission to invoke the Lambda function

## License

MIT
