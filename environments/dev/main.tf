provider "aws" {
  region = var.aws_region
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
  source                = "../../modules/iam"
  prefix                = "${var.project_name}-${var.environment}"
  region                = var.aws_region
  enable_aoss_access    = true
  enable_bedrock_access = true
  embed_model_id        = var.embed_model_id
  claude_model_id       = var.claude_model_id
}

module "opensearch" {
  source          = "../../modules/opensearch"
  prefix          = "${var.project_name}-${var.environment}"
  collection_name = var.opensearch_collection_name
  access_principal_arns = [
    module.iam.ingest_role_arn,
    module.iam.query_role_arn,
  ]
}

module "lambda" {
  source             = "../../modules/lambda"
  prefix             = "${var.project_name}-${var.environment}"
  ingest_source_dir  = "${path.root}/../../lambdas/ingest"
  query_source_dir   = "${path.root}/../../lambdas/query"
  layer_source_dir   = "${path.root}/../../lambdas/layer"
  ingest_role_arn    = module.iam.ingest_role_arn
  query_role_arn     = module.iam.query_role_arn
  lambda_memory_mb   = 512
  lambda_timeout_sec = 60
  common_lambda_env = {
    OPENSEARCH_ENDPOINT = module.opensearch.collection_endpoint
    INDEX_NAME          = var.opensearch_index_name
  }
  claude_model_id = var.claude_model_id
}

module "cloudfront" {
  source                = "../../modules/cloudfront"
  prefix                = "${var.project_name}-${var.environment}"
  ui_bucket_arn         = module.s3_ui.bucket_arn
  ui_bucket_domain_name = module.s3_ui.bucket_regional_domain_name
  price_class           = var.cloudfront_price_class
}
