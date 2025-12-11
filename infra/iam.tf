# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution" {
  name               = "${var.function_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name        = "${var.function_name}-execution-role"
    Environment = var.environment
  }
}

# Lambda Assume Role Policy
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# CloudWatch Logs Policy
resource "aws_iam_policy" "lambda_logs" {
  name        = "${var.function_name}-logs-policy"
  description = "IAM policy for logging from Lambda"
  policy      = data.aws_iam_policy_document.lambda_logs.json

  tags = {
    Name        = "${var.function_name}-logs-policy"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*",
    ]
  }
}

# S3 Access Policy for reading emails
resource "aws_iam_policy" "lambda_s3" {
  name        = "${var.function_name}-s3-policy"
  description = "IAM policy for S3 access from Lambda"
  policy      = data.aws_iam_policy_document.lambda_s3.json

  tags = {
    Name        = "${var.function_name}-s3-policy"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.ses_email_bucket}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.ses_email_bucket}",
    ]
  }
}

# SES Send Email Policy
resource "aws_iam_policy" "lambda_ses" {
  name        = "${var.function_name}-ses-policy"
  description = "IAM policy for sending emails via SES from Lambda"
  policy      = data.aws_iam_policy_document.lambda_ses.json

  tags = {
    Name        = "${var.function_name}-ses-policy"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "lambda_ses" {
  statement {
    effect = "Allow"

    actions = [
      "ses:SendRawEmail",
    ]

    resources = ["*"]
  }
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_logs.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ses" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_ses.arn
}
