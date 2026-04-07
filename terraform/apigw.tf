# ── REST API ───────────────────────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "rag" {
  name        = "${local.prefix}-api"
  description = "RAG product catalog API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ── /products resource ─────────────────────────────────────────────────────

resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  parent_id   = aws_api_gateway_rest_api.rag.root_resource_id
  path_part   = "products"
}

resource "aws_api_gateway_method" "products_post" {
  rest_api_id   = aws_api_gateway_rest_api.rag.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_post" {
  rest_api_id             = aws_api_gateway_rest_api.rag.id
  resource_id             = aws_api_gateway_resource.products.id
  http_method             = aws_api_gateway_method.products_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ingest.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke_ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rag.execution_arn}/*/*"
}

# CORS preflight for /products
resource "aws_api_gateway_method" "products_options" {
  rest_api_id   = aws_api_gateway_rest_api.rag.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_options" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "products_options_200" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "products_options" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.products.id
  http_method = aws_api_gateway_method.products_options.http_method
  status_code = aws_api_gateway_method_response.products_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ── /query resource ────────────────────────────────────────────────────────

resource "aws_api_gateway_resource" "query" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  parent_id   = aws_api_gateway_rest_api.rag.root_resource_id
  path_part   = "query"
}

resource "aws_api_gateway_method" "query_post" {
  rest_api_id   = aws_api_gateway_rest_api.rag.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_post" {
  rest_api_id             = aws_api_gateway_rest_api.rag.id
  resource_id             = aws_api_gateway_resource.query.id
  http_method             = aws_api_gateway_method.query_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.query.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke_query" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rag.execution_arn}/*/*"
}

# CORS preflight for /query
resource "aws_api_gateway_method" "query_options" {
  rest_api_id   = aws_api_gateway_rest_api.rag.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_options" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "query_options_200" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "query_options" {
  rest_api_id = aws_api_gateway_rest_api.rag.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = aws_api_gateway_method_response.query_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ── Deployment & Stage ─────────────────────────────────────────────────────

resource "aws_api_gateway_deployment" "rag" {
  rest_api_id = aws_api_gateway_rest_api.rag.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.products.id,
      aws_api_gateway_method.products_post.id,
      aws_api_gateway_integration.products_post.id,
      aws_api_gateway_resource.query.id,
      aws_api_gateway_method.query_post.id,
      aws_api_gateway_integration.query_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "rag" {
  rest_api_id   = aws_api_gateway_rest_api.rag.id
  deployment_id = aws_api_gateway_deployment.rag.id
  stage_name    = var.api_stage_name

  access_log_destination_arn = aws_cloudwatch_log_group.apigw.arn

  default_route_settings {
    # throttling for cost protection
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = 14
}
