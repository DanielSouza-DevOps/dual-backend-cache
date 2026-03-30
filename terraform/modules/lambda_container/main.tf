resource "aws_iam_role" "this" {
  name = substr(replace("${var.name_prefix}-${var.service_key}-lambda", "_", "-"), 0, 64)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "this" {
  function_name = "${var.name_prefix}-${var.service_key}"
  role          = aws_iam_role.this.arn
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = [var.architecture]

  package_type = "Zip"

  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version != null && var.s3_object_version != "" ? var.s3_object_version : null

  source_code_hash = var.source_code_hash
  handler          = var.handler
  runtime          = var.runtime

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  tags = {
    Name = "${var.name_prefix}-${var.service_key}"
  }

  lifecycle {
    precondition {
      condition = (
        length(trimspace(var.s3_bucket)) > 0 &&
        length(trimspace(var.s3_key)) > 0 &&
        length(trimspace(var.source_code_hash)) > 0 &&
        length(trimspace(var.handler)) > 0 &&
        length(trimspace(var.runtime)) > 0
      )
      error_message = "Zip Lambda via S3 requires s3_bucket, s3_key, source_code_hash, handler, and runtime."
    }
  }
}
