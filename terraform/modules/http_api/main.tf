# REST API Gateway (v1) — better LocalStack Community support than HTTP API (v2).

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_api_gateway_rest_api" "this" {
  name = substr(replace("${var.name_prefix}-api", "_", "-"), 0, 128)

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.name_prefix}-api"
  }
}

resource "aws_api_gateway_resource" "segment" {
  for_each = var.proxy_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "root" {
  for_each = var.proxy_routes

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.segment[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root" {
  for_each = var.proxy_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.segment[each.key].id
  http_method = aws_api_gateway_method.root[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
}

resource "aws_api_gateway_resource" "proxy" {
  for_each = var.proxy_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.segment[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  for_each = var.proxy_routes

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  for_each = var.proxy_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy[each.key].id
  http_method = aws_api_gateway_method.proxy[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(join(",", concat(
      [for k, v in aws_api_gateway_integration.root : v.id],
      [for k, v in aws_api_gateway_integration.proxy : v.id],
    )))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.root,
    aws_api_gateway_integration.proxy,
  ]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id     = aws_api_gateway_rest_api.this.id
  stage_name      = var.stage_name

  tags = {
    Name = "${var.name_prefix}-stage-${var.stage_name}"
  }
}
