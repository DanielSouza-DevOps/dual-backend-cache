variable "aws_region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "use_localstack" {
  type        = bool
  description = "false (default): real AWS account — credentials via ~/.aws/credentials, AWS_PROFILE, env vars, or IAM (OIDC/role). true: LocalStack at localstack_endpoint."
  default     = false
}

variable "localstack_endpoint" {
  type        = string
  description = "LocalStack edge URL. Use http://127.0.0.1:4566 (not \"localhost\") on macOS/Linux if Terraform hits [::1]:4566 and connection is refused."
  default     = "http://127.0.0.1:4566"
}

variable "project_name" {
  type        = string
  description = "Prefix for resource names."
  default     = "dual-backend-cache"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, staging, prod)."
  default     = "dev"
}

variable "lambda_pip_command" {
  type        = string
  description = "pip command for the Python Lambda zip bundle (e.g. python3 -m pip)."
  default     = "python3 -m pip"
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda function timeout in seconds."
  default     = 10
}

variable "lambda_memory_node" {
  type        = number
  description = "Node Lambda memory in MB."
  default     = 256
}

variable "lambda_memory_python" {
  type        = number
  description = "Python Lambda memory in MB."
  default     = 256
}

variable "cache_ttl_seconds_node" {
  type        = number
  description = "In-memory cache TTL for the Node Lambda in seconds. Passed as CACHE_TTL_SEC."
  default     = 10
}

variable "cache_ttl_seconds_python" {
  type        = number
  description = "In-memory cache TTL for the Python Lambda in seconds. Passed as CACHE_TTL_SEC."
  default     = 60
}

variable "lambda_architecture" {
  type        = string
  description = "Lambda zip architecture (x86_64 or arm64). Python bundle manylinux pip must match."
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "lambda_architecture must be x86_64 or arm64."
  }
}

variable "lambda_runtime_node_zip" {
  type        = string
  description = "Node Lambda zip runtime. LocalStack 3.8.x often allows nodejs18.x (sometimes nodejs20.x); nodejs22.x often fails."
  default     = "nodejs18.x"
}

variable "lambda_runtime_python_zip" {
  type        = string
  description = "Python Lambda zip runtime. LocalStack often accepts python3.11; python3.12 may be rejected depending on version."
  default     = "python3.11"
}

variable "alb_route_node" {
  type        = string
  description = "HTTP API path prefix for Node, e.g. /node."
  default     = "/node"
}

variable "alb_route_python" {
  type        = string
  description = "HTTP API path prefix for Python."
  default     = "/python"
}

variable "api_gateway_stage_name" {
  type        = string
  description = "REST API Gateway (v1) stage name."
  default     = "dev"
}

variable "lambda_artifacts_bucket_force_destroy" {
  type        = bool
  description = "If true, destroy removes the artifacts S3 bucket even when it contains objects (typical for dev/LocalStack)."
  default     = true
}
