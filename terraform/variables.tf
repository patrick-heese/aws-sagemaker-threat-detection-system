variable "project_name" {
  description = "Project tag value for all resources/prefixes"
  type        = string
  default     = "sagemaker-threat-detection"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name to create (stores data/artifacts)"
  type        = string
}

variable "pipeline_name" {
  description = "Name of the SageMaker Pipeline invoked by Lambda"
  type        = string
  default     = "simple-cybersecurity-pipeline"
}

variable "lambda_name" {
  description = "Lambda function name (S3→Lambda trigger)"
  type        = string
  default     = "trigger-cybersecurity-pipeline"
}

variable "sagemaker_role_name" {
  description = "IAM role name for SageMaker execution"
  type        = string
  default     = "SageMakerCybersecurityRole"
}

variable "s3_new_data_prefix" {
  description = "S3 key prefix that triggers the Lambda (e.g., new-data/)"
  type        = string
  default     = "new-data/"
}
