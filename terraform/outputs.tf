output "http_api_endpoint" {
  description = "URL prefix. Do not stop at _user_request_ only — append the full resource path (otherwise LocalStack may return InternalError). See example_url_*."
  value       = local.http_api_client_base
}

output "example_url_node_health" {
  description = "Full example URL (Node Lambda via API Gateway)."
  value       = "${local.http_api_client_base}${local.api_node_path}/health"
}

output "example_url_node_static" {
  description = "Static text/plain (GET service root for Node, e.g. /node on API GW)."
  value       = "${local.http_api_client_base}${local.api_node_path}"
}

output "example_url_python_health" {
  description = "Full example URL (Python Lambda via API Gateway)."
  value       = "${local.http_api_client_base}${local.api_python_path}/health"
}

output "example_url_python_time" {
  description = "Server time (GET /time on Python Lambda)."
  value       = "${local.http_api_client_base}${local.api_python_path}/time"
}

output "http_api_invoke_url_aws_format" {
  description = "invoke_url style from the provider (useful on real AWS; LocalStack host is not public internet)."
  value       = module.http_api.api_endpoint
}

output "lambda_artifacts_bucket" {
  description = "S3 bucket where Lambda .zip packages are published (versioning enabled)."
  value       = module.lambda_artifacts_s3.bucket
}

output "lambda_artifacts_s3_keys" {
  description = "S3 keys for Node and Python packages."
  value = {
    node   = module.lambda_artifacts_s3.node_package_key
    python = module.lambda_artifacts_s3.python_package_key
  }
}

output "lambda_artifacts_s3_versions" {
  description = "Current VersionId for each package in S3 (used as Lambda s3_object_version)."
  value = {
    node   = module.lambda_artifacts_s3.node_package_version_id
    python = module.lambda_artifacts_s3.python_package_version_id
  }
}

output "lambda_node_function_name" {
  value = module.node_lambda.function_name
}

output "lambda_python_function_name" {
  value = module.python_lambda.function_name
}
