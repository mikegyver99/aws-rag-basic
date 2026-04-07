# ── Package Lambda functions ───────────────────────────────────────────────

data "archive_file" "ingest" {
  type        = "zip"
  source_dir  = local.ingest_source_dir
  output_path = "${path.module}/.build/ingest.zip"
}

data "archive_file" "query" {
  type        = "zip"
  source_dir  = local.query_source_dir
  output_path = "${path.module}/.build/query.zip"
}

# ── Ingest Lambda ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "ingest" {
  function_name    = "${local.prefix}-ingest"
  description      = "Parses JSON, chunks, embeds, and writes to OpenSearch"
  role             = aws_iam_role.ingest_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_sec

  environment {
    variables = merge(local.common_lambda_env, {
      DATA_BUCKET = aws_s3_bucket.data.id
    })
  }

  depends_on = [aws_opensearchserverless_collection.products]
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = 14
}

# ── Query Lambda ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "query" {
  function_name    = "${local.prefix}-query"
  description      = "Embeds a question, runs k-NN search, calls Claude, returns answer"
  role             = aws_iam_role.query_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256
  memory_size      = var.lambda_memory_mb
  timeout          = var.lambda_timeout_sec

  environment {
    variables = merge(local.common_lambda_env, {
      CLAUDE_MODEL_ID = var.claude_model_id
    })
  }

  depends_on = [aws_opensearchserverless_collection.products]
}

resource "aws_cloudwatch_log_group" "query" {
  name              = "/aws/lambda/${aws_lambda_function.query.function_name}"
  retention_in_days = 14
}
