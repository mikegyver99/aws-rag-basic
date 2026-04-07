# ── OpenSearch Serverless encryption policy ────────────────────────────────

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${local.prefix}-enc"
  type        = "encryption"
  description = "AWS-managed KMS encryption for the ${var.opensearch_collection_name} collection"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.opensearch_collection_name}"]
    }]
    AWSOwnedKey = true
  })
}

# ── OpenSearch Serverless network policy ───────────────────────────────────

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${local.prefix}-net"
  type        = "network"
  description = "Public access for the ${var.opensearch_collection_name} collection"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.opensearch_collection_name}"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${var.opensearch_collection_name}"]
      },
    ]
    AllowFromPublic = true
  }])
}

# ── OpenSearch Serverless data access policy ───────────────────────────────

resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${local.prefix}-data"
  type        = "data"
  description = "Lambda read/write access to the ${var.opensearch_collection_name} collection"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${var.opensearch_collection_name}/*"]
        Permission   = ["aoss:*"]
      },
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.opensearch_collection_name}"]
        Permission   = ["aoss:*"]
      },
    ]
    Principal = [
      aws_iam_role.ingest_lambda.arn,
      aws_iam_role.query_lambda.arn,
      "arn:aws:iam::${local.account_id}:root",
    ]
  }])
}

# ── OpenSearch Serverless collection ──────────────────────────────────────

resource "aws_opensearchserverless_collection" "products" {
  name        = var.opensearch_collection_name
  type        = "VECTORSEARCH"
  description = "k-NN product catalog vector store"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]
}
