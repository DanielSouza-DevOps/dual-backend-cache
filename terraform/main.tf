locals {
  name_prefix = "${var.project_name}-${var.environment}"

  node_app_dir   = abspath("${path.module}/../node-app")
  python_app_dir = abspath("${path.module}/../python-app")

  api_node_path = trimsuffix(
    startswith(var.alb_route_node, "/") ? var.alb_route_node : "/${var.alb_route_node}",
    "/"
  )
  api_python_path = trimsuffix(
    startswith(var.alb_route_python, "/") ? var.alb_route_python : "/${var.alb_route_python}",
    "/"
  )

  http_api_client_base = var.use_localstack ? "${trimsuffix(var.localstack_endpoint, "/")}/restapis/${module.http_api.rest_api_id}/${var.api_gateway_stage_name}/_user_request_" : trimsuffix(module.http_api.api_endpoint, "/")

  node_s3_version = module.lambda_artifacts_s3.node_package_version_id != "" ? module.lambda_artifacts_s3.node_package_version_id : null
  python_s3_version = module.lambda_artifacts_s3.python_package_version_id != "" ? module.lambda_artifacts_s3.python_package_version_id : null
}

module "lambda_artifacts_s3" {
  source = "./modules/lambda_artifacts_s3"

  name_prefix       = local.name_prefix
  force_destroy     = var.lambda_artifacts_bucket_force_destroy
  node_zip_source   = data.archive_file.node_lambda_zip.output_path
  python_zip_source = data.archive_file.python_lambda_zip.output_path
}

module "node_lambda" {
  source = "./modules/lambda_container"

  name_prefix         = local.name_prefix
  service_key         = "node"
  s3_bucket           = module.lambda_artifacts_s3.bucket
  s3_key              = module.lambda_artifacts_s3.node_package_key
  s3_object_version   = local.node_s3_version
  source_code_hash    = data.archive_file.node_lambda_zip.output_base64sha256
  handler             = "lambda.handler"
  runtime             = var.lambda_runtime_node_zip
  timeout             = var.lambda_timeout_seconds
  memory_size         = var.lambda_memory_node
  architecture        = var.lambda_architecture
  environment = {
    PATH_PREFIX              = local.api_node_path
    API_GATEWAY_STAGE_NAME = var.api_gateway_stage_name
    CACHE_TTL_SEC          = tostring(var.cache_ttl_seconds_node)
  }

  depends_on = [module.lambda_artifacts_s3]
}

module "python_lambda" {
  source = "./modules/lambda_container"

  name_prefix         = local.name_prefix
  service_key         = "python"
  s3_bucket           = module.lambda_artifacts_s3.bucket
  s3_key              = module.lambda_artifacts_s3.python_package_key
  s3_object_version   = local.python_s3_version
  source_code_hash    = data.archive_file.python_lambda_zip.output_base64sha256
  handler             = "handler.handler"
  runtime             = var.lambda_runtime_python_zip
  timeout             = var.lambda_timeout_seconds
  memory_size         = var.lambda_memory_python
  architecture        = var.lambda_architecture
  environment = {
    PATH_PREFIX              = local.api_python_path
    API_GATEWAY_STAGE_NAME = var.api_gateway_stage_name
    CACHE_TTL_SEC          = tostring(var.cache_ttl_seconds_python)
  }

  depends_on = [module.lambda_artifacts_s3]
}

module "http_api" {
  source = "./modules/http_api"

  name_prefix = local.name_prefix
  stage_name  = var.api_gateway_stage_name

  proxy_routes = {
    node = {
      path_part         = trimprefix(local.api_node_path, "/")
      lambda_invoke_arn = module.node_lambda.invoke_arn
    }
    python = {
      path_part         = trimprefix(local.api_python_path, "/")
      lambda_invoke_arn = module.python_lambda.invoke_arn
    }
  }
}

resource "aws_lambda_permission" "node_apigw" {
  statement_id  = "AllowAPIGatewayInvokeNode"
  action        = "lambda:InvokeFunction"
  function_name = module.node_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "python_apigw" {
  statement_id  = "AllowAPIGatewayInvokePython"
  action        = "lambda:InvokeFunction"
  function_name = module.python_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.http_api.execution_arn}/*/*"
}
