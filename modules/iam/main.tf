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

output "ingest_role_arn" {
  value = aws_iam_role.ingest_lambda.arn
}

output "query_role_arn" {
  value = aws_iam_role.query_lambda.arn
}
