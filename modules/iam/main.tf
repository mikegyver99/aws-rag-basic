resource "aws_iam_role" "ingest_lambda" {
  name = "${var.prefix}-ingest-lambda-role"

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

resource "aws_iam_role_policy_attachment" "ingest_vpc_access" {
  role       = aws_iam_role.ingest_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "query_lambda" {
  name = "${var.prefix}-query-lambda-role"

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

resource "aws_iam_role_policy_attachment" "query_vpc_access" {
  role       = aws_iam_role.query_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Inline policy granting Lambdas read/write access to the S3 vector index bucket
resource "aws_iam_role_policy" "ingest_s3_index_access" {
  name  = "${var.prefix}-ingest-s3-index-access"
  role  = aws_iam_role.ingest_lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = "${var.index_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = var.index_bucket_arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "query_s3_index_access" {
  name  = "${var.prefix}-query-s3-index-access"
  role  = aws_iam_role.query_lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${var.index_bucket_arn}/*"
      },
    ]
  })
}

# Optional inline policy granting Bedrock InvokeModel permission to Lambdas
locals {
  specific_bedrock_resources = compact([
    var.embed_model_id != "" ? "arn:aws:bedrock:${var.region}::foundation-model/${var.embed_model_id}" : "",
    var.claude_model_id != "" ? "arn:aws:bedrock:${var.region}::foundation-model/${var.claude_model_id}" : "",
  ])

  bedrock_resources = length(local.specific_bedrock_resources) > 0 ? local.specific_bedrock_resources : ["arn:aws:bedrock:${var.region}::foundation-model/*"]
}

resource "aws_iam_role_policy" "ingest_bedrock_access" {
  count = var.enable_bedrock_access ? 1 : 0
  name  = "${var.prefix}-ingest-bedrock-access"
  role  = aws_iam_role.ingest_lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.bedrock_resources
      }
    ]
  })
}

resource "aws_iam_role_policy" "query_bedrock_access" {
  count = var.enable_bedrock_access ? 1 : 0
  name  = "${var.prefix}-query-bedrock-access"
  role  = aws_iam_role.query_lambda.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = local.bedrock_resources
      }
    ]
  })
}

output "ingest_role_arn" {
  value = aws_iam_role.ingest_lambda.arn
}

output "query_role_arn" {
  value = aws_iam_role.query_lambda.arn
}
