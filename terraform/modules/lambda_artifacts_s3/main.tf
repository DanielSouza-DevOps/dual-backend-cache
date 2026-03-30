resource "aws_s3_bucket" "lambda_artifacts" {
  # AWS limit: bucket_prefix max 37 characters before the random suffix.
  bucket_prefix = substr(replace("${var.name_prefix}-lambda-", "_", "-"), 0, 37)
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "node_lambda_package" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.node_object_key
  source = var.node_zip_source
  etag   = filemd5(var.node_zip_source)

  depends_on = [aws_s3_bucket_versioning.lambda_artifacts]
}

resource "aws_s3_object" "python_lambda_package" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.python_object_key
  source = var.python_zip_source
  etag   = filemd5(var.python_zip_source)

  depends_on = [aws_s3_bucket_versioning.lambda_artifacts]
}
