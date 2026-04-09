data "archive_file" "ingest" {
  type        = "zip"
  source_dir  = var.ingest_source_dir
  output_path = "${path.module}/.build/ingest.zip"
}

data "archive_file" "query" {
  type        = "zip"
  source_dir  = var.query_source_dir
  output_path = "${path.module}/.build/query.zip"
}

locals {
  layer_name = var.lambda_layer_name != "" ? var.lambda_layer_name : "${var.prefix}-python-deps"
}

resource "aws_lambda_layer_version" "deps" {
  count               = var.enable_lambda_layer ? 1 : 0
  # Use the root module path so Terraform running in the environment folder
  # picks up the artifact placed at environments/<env>/layer.zip by CI.
  filename            = "${path.root}/layer.zip"
  layer_name          = local.layer_name
  compatible_runtimes = ["python3.12"]
  description         = "${var.prefix}-python-deps"
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.prefix}-ingest"
  role             = var.ingest_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_sec

  layers = var.enable_lambda_layer ? [aws_lambda_layer_version.deps[0].arn] : []

  environment {
    variables = merge(var.common_lambda_env, {})
  }
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "query" {
  function_name    = "${var.prefix}-query"
  role             = var.query_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_sec

  environment {
    variables = merge(var.common_lambda_env, {
      CLAUDE_MODEL_ID = var.claude_model_id
    })
  }

  layers = var.enable_lambda_layer ? [aws_lambda_layer_version.deps[0].arn] : []
}

resource "aws_cloudwatch_log_group" "query" {
  name              = "/aws/lambda/${aws_lambda_function.query.function_name}"
  retention_in_days = 14
}

output "ingest_function_arn" {
  value = aws_lambda_function.ingest.arn
}

output "query_function_arn" {
  value = aws_lambda_function.query.arn
}

output "ingest_function_invoke_arn" {
  value = aws_lambda_function.ingest.invoke_arn
}

output "query_function_invoke_arn" {
  value = aws_lambda_function.query.invoke_arn
}
