data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Resource name prefix: e.g. "rag-basic-dev"
  prefix = "${var.project_name}-${var.environment}"

  # Paths to Lambda source code (relative to the Terraform root)
  ingest_source_dir = "${path.root}/../lambdas/ingest"
  query_source_dir  = "${path.root}/../lambdas/query"

  # Data files
  data_dir = "${path.root}/../data"

  # Common Lambda environment variables
  common_lambda_env = {
    OPENSEARCH_ENDPOINT = "https://${aws_opensearchserverless_collection.products.collection_endpoint}"
    INDEX_NAME          = var.opensearch_index_name
    EMBED_MODEL_ID      = var.embed_model_id
    CHUNK_SIZE          = tostring(var.chunk_size_tokens)
    TOP_K               = tostring(var.top_k)
  }
}
