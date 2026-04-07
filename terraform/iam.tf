# ── IAM role for Ingest Lambda ─────────────────────────────────────────────

resource "aws_iam_role" "ingest_lambda" {
  name = "${local.prefix}-ingest-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ingest_basic_execution" {
  role       = aws_iam_role.ingest_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ingest_lambda_inline" {
  name = "${local.prefix}-ingest-lambda-policy"
  role = aws_iam_role.ingest_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read the data S3 bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*",
        ]
      },
      # Bedrock — embed model
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.embed_model_id}"
      },
      # OpenSearch Serverless — write
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll",
        ]
        Resource = aws_opensearchserverless_collection.products.arn
      },
    ]
  })
}

# ── IAM role for Query Lambda ──────────────────────────────────────────────

resource "aws_iam_role" "query_lambda" {
  name = "${local.prefix}-query-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "query_basic_execution" {
  role       = aws_iam_role.query_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "query_lambda_inline" {
  name = "${local.prefix}-query-lambda-policy"
  role = aws_iam_role.query_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bedrock — embed + Claude
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/${var.embed_model_id}",
          "arn:aws:bedrock:${local.region}::foundation-model/${var.claude_model_id}",
        ]
      },
      # OpenSearch Serverless — read
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = aws_opensearchserverless_collection.products.arn
      },
    ]
  })
}
