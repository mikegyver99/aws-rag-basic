output "api_endpoint" {
  description = "API Gateway base URL. Append /products or /query."
  value       = "https://${aws_api_gateway_rest_api.rag.id}.execute-api.${local.region}.amazonaws.com/${var.api_stage_name}"
}

output "chat_ui_url" {
  description = "CloudFront HTTPS URL for the chat UI."
  value       = "https://${aws_cloudfront_distribution.ui.domain_name}"
}

output "data_bucket_name" {
  description = "S3 bucket for bulk JSON ingestion. Drop a .json file here to trigger the Ingest Lambda."
  value       = aws_s3_bucket.data.id
}

output "ui_bucket_name" {
  description = "S3 bucket that hosts the static chat UI."
  value       = aws_s3_bucket.ui.id
}

output "opensearch_endpoint" {
  description = "OpenSearch Serverless collection endpoint (HTTPS)."
  value       = aws_opensearchserverless_collection.products.collection_endpoint
}

output "ingest_lambda_name" {
  description = "Name of the Ingest Lambda function."
  value       = aws_lambda_function.ingest.function_name
}

output "query_lambda_name" {
  description = "Name of the Query Lambda function."
  value       = aws_lambda_function.query.function_name
}
