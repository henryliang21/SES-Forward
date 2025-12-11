output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ses_forwarder.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ses_forwarder.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function (for use in SES receipt rules)"
  value       = aws_lambda_function.ses_forwarder.invoke_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
