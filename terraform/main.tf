# Helpers
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------
# S3 Bucket
# -----------------------------
resource "aws_s3_bucket" "data_bucket" {
  bucket = var.bucket_name
  # Destroy doesn't fail if objects remain:
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.data_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.data_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# IAM: SageMaker Role
# -----------------------------
data "aws_iam_policy_document" "sagemaker_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sagemaker_role" {
  name               = var.sagemaker_role_name
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume.json
}

# NOTE: Broad access to SageMaker kept intentionally for the demo.
resource "aws_iam_role_policy_attachment" "sm_full" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# IAM policy scoped to S3 bucket
data "aws_iam_policy_document" "sm_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.data_bucket.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.data_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "sm_s3_policy" {
  name   = "${var.project}-sagemaker-s3"
  policy = data.aws_iam_policy_document.sm_s3.json
}

resource "aws_iam_role_policy_attachment" "sm_s3_attach" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sm_s3_policy.arn
}

# -----------------------------
# IAM: Lambda Role
# -----------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Logs for Lambda
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to start the specific SageMaker Pipeline (least-privilege)
data "aws_iam_policy_document" "lambda_sm" {
  statement {
    effect  = "Allow"
    actions = ["sagemaker:StartPipelineExecution"]
    resources = [
      "arn:aws:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:pipeline/${var.pipeline_name}"
    ]
  }
}

resource "aws_iam_policy" "lambda_sm_policy" {
  name   = "${var.project}-lambda-start-pipeline"
  policy = data.aws_iam_policy_document.lambda_sm.json
}

resource "aws_iam_role_policy_attachment" "lambda_sm_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sm_policy.arn
}

# -----------------------------
# Lambda Function
# -----------------------------
# Zips ../src/triggerpipeline_function/* into triggerpipeline_lambda.zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../src/triggerpipeline_function"
  output_path = "../src/triggerpipeline_function/triggerpipeline_lambda.zip"
}

resource "aws_lambda_function" "trigger" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  # Match your filename: triggerpipeline_lambda.py
  handler          = "triggerpipeline_lambda.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Small QoL defaults
  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      PIPELINE_NAME = var.pipeline_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_sm_attach
  ]
}

resource "aws_cloudwatch_log_group" "lambda_lg" {
  name              = "/aws/lambda/${aws_lambda_function.trigger.function_name}"
  retention_in_days = 14
}

# -----------------------------
# S3 -> Lambda Notification
# -----------------------------
# NOTE: This resource manages ALL bucket notifications for this bucket.
# Avoid creating notifications in the console (Terraform will overwrite).
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
}

resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_new_data_prefix
    # filter_suffix     = ".txt"  # optional
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
