output "bucket_name" {
  description = "S3 bucket name for data/artifacts."
  value       = aws_s3_bucket.data_bucket.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.data_bucket.arn
}

output "sagemaker_role_arn" {
  description = "SageMaker execution role ARN."
  value       = aws_iam_role.sagemaker_role.arn
}

output "lambda_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.trigger.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.trigger.arn
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN."
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_log_group" {
  description = "CloudWatch Logs group for the Lambda."
  value       = aws_cloudwatch_log_group.lambda_lg.name
}
