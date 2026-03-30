output "rest_api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "api_endpoint" {
  description = "Stage base URL (REST). E.g. https://{id}.execute-api.{region}.amazonaws.com/{stage}"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "execution_arn" {
  description = "arn:aws:execute-api:... pattern for Lambda permissions (same use as in root)."
  value       = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.this.id}"
}
