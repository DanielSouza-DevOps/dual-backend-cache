output "bucket" {
  description = "Bucket name (bucket attribute)."
  value       = aws_s3_bucket.lambda_artifacts.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.lambda_artifacts.arn
}

output "node_package_key" {
  value = aws_s3_object.node_lambda_package.key
}

output "python_package_key" {
  value = aws_s3_object.python_lambda_package.key
}

output "node_package_version_id" {
  value = aws_s3_object.node_lambda_package.version_id
}

output "python_package_version_id" {
  value = aws_s3_object.python_lambda_package.version_id
}
