provider "aws" {
  region = var.aws_region

  # LocalStack: dummy credentials and skip real AWS validation.
  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      apigateway     = var.localstack_endpoint
      apigatewayv2   = var.localstack_endpoint
      iam            = var.localstack_endpoint
      lambda         = var.localstack_endpoint
      logs           = var.localstack_endpoint
      s3             = var.localstack_endpoint
      sts            = var.localstack_endpoint
    }
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
