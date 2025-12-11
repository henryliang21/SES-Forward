# Create deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../"
  output_path = "${path.module}/lambda_function.zip"

  excludes = [
    ".git",
    ".gitignore",
    "infra",
    "README.md",
    "LICENSE",
    "function.zip",
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
  }
}

# Lambda Function
resource "aws_lambda_function" "ses_forwarder" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "nodejs22.x"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      FORWARD_TO_EMAIL = var.forward_to_email
      S3_BUCKET        = var.ses_email_bucket
      S3_PREFIX        = var.ses_s3_prefix
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_s3,
    aws_iam_role_policy_attachment.lambda_ses,
  ]

  tags = {
    Name        = var.function_name
    Environment = var.environment
  }
}

# Lambda permission for SES to invoke
resource "aws_lambda_permission" "allow_ses" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_forwarder.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}
