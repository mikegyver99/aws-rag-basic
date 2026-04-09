provider "aws" {
  region = var.aws_region
}

# Minimal example: create (or reference) a VPC endpoint for OpenSearch Serverless
# so the opensearch module can restrict network access to this VPCE.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "opensearch_vpce_sg" {
  name        = "${var.project_name}-${var.environment}-opensearch-vpce-sg"
  description = "Security group for OpenSearch Serverless VPC endpoint"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_opensearchserverless_vpc_endpoint" "opensearch_vpce" {
  name               = "${var.project_name}-${var.environment}-opensearch-vpce"
  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.opensearch_vpce_sg.id]
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambdas to reach AOSS VPCE"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# Allow Lambda SG to reach the OpenSearch VPCE SG on HTTPS
resource "aws_security_group_rule" "allow_from_lambda_to_vpce" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.opensearch_vpce_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}

module "s3_data" {
  source = "../../modules/s3"
  name   = "${var.project_name}-${var.environment}-data"
  # keep data bucket destroyable for dev
  force_destroy = true
}

module "s3_ui" {
  source        = "../../modules/s3"
  name          = "${var.project_name}-${var.environment}-ui"
  force_destroy = true
}

module "apigw" {
  source                   = "../../modules/apigw"
  prefix                   = "${var.project_name}-${var.environment}"
  api_stage_name           = var.api_stage_name
  ingest_lambda_arn        = module.lambda.ingest_function_arn
  query_lambda_arn         = module.lambda.query_function_arn
  ingest_lambda_invoke_arn = module.lambda.ingest_function_invoke_arn
  query_lambda_invoke_arn  = module.lambda.query_function_invoke_arn
}

module "iam" {
  source = "../../modules/iam"
  prefix = "${var.project_name}-${var.environment}"
  region = var.aws_region
}

module "opensearch" {
  source          = "../../modules/opensearch"
  prefix          = "${var.project_name}-${var.environment}"
  collection_name = var.opensearch_collection_name
  # Restrict network policy to the created VPCE
  source_vpce_ids = [aws_opensearchserverless_vpc_endpoint.opensearch_vpce.id]
}

module "lambda" {
  source             = "../../modules/lambda"
  prefix             = "${var.project_name}-${var.environment}"
  ingest_source_dir  = "${path.root}/../../lambdas/ingest"
  query_source_dir   = "${path.root}/../../lambdas/query"
  ingest_role_arn    = module.iam.ingest_role_arn
  query_role_arn     = module.iam.query_role_arn
  lambda_memory_mb   = 512
  lambda_timeout_sec = 60
  common_lambda_env = {
    OPENSEARCH_ENDPOINT = module.opensearch.collection_endpoint
    INDEX_NAME          = var.opensearch_index_name
  }
  claude_model_id        = var.claude_model_id
  vpc_subnet_ids         = data.aws_subnets.default.ids
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]
}

module "cloudfront" {
  source                = "../../modules/cloudfront"
  prefix                = "${var.project_name}-${var.environment}"
  ui_bucket_arn         = module.s3_ui.bucket_arn
  ui_bucket_domain_name = module.s3_ui.bucket_regional_domain_name
  price_class           = var.cloudfront_price_class
}
