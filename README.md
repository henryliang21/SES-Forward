# SES Email Forwarder

AWS Lambda function that automatically forwards emails received via Amazon SES to a designated email address.

## Features

- Forwards emails received by SES to a specified email address
- Preserves original email content and formatting
- Adds forwarding information in email headers
- Sets Reply-To to the original sender for easy responses
- Stores original recipient information in X-headers

## Prerequisites

- AWS Account with SES configured
- SES domain or email address verified
- SES receipt rule with S3 action configured
- Node.js 22+ for local development

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

``` bash
aws s3 mb s3://your-ses-email-bucket
```

#### Create SES Receipt Rule

1. Go to SES Console > Email Receiving > Rule Sets
2. Create a new rule set or use an existing one
3. Add a rule with:
   - Recipients: The email addresses you want to forward (e.g., `incoming@yourdomain.com`)
   - Actions:
     - First action: S3 - Store to your S3 bucket
     - Second action: Lambda - Invoke this function

### 3. Deploy Lambda Function

#### Package the Function

```bash
zip -r function.zip index.js node_modules package.json
```

#### Create Lambda Function

```bash
aws lambda create-function \
  --function-name SESEmailForwarder \
  --runtime nodejs22.x \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-ses-execution-role \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --environment Variables="{FORWARD_TO_EMAIL=your-email@example.com}" \
  --timeout 30 \
  --memory-size 256
```

#### Update Lambda Function (for subsequent deployments)

```bash
aws lambda update-function-code \
  --function-name SESEmailForwarder \
  --zip-file fileb://function.zip
```

### 4. Configure IAM Role

The Lambda execution role needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-ses-email-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5. Grant SES Permission to Invoke Lambda

```bash
aws lambda add-permission \
  --function-name SESEmailForwarder \
  --statement-id AllowSESInvoke \
  --action lambda:InvokeFunction \
  --principal ses.amazonaws.com \
  --source-account YOUR_ACCOUNT_ID
```

## Environment Variables

- `FORWARD_TO_EMAIL` (required): The email address to forward all received emails to

## How It Works

1. SES receives an email
2. SES stores the email in S3 bucket
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
