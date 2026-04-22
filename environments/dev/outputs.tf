output "api_endpoint" {
  description = "API Gateway base URL."
  value       = "https://${module.apigw.rest_api_id}.execute-api.${var.aws_region}.amazonaws.com/${module.apigw.stage_name}"
}

output "chat_ui_url" {
  description = "CloudFront HTTPS URL for the chat UI."
  value       = "https://${module.cloudfront.domain_name}"
}

output "data_bucket_name" {
  description = "S3 bucket for bulk JSON ingestion."
  value       = module.s3_data.bucket_id
}

output "ui_bucket_name" {
  description = "S3 bucket that hosts the static chat UI."
  value       = module.s3_ui.bucket_id
}

output "vector_index_location" {
  description = "S3 location of the vector index JSON used for retrieval."
  value       = "s3://${module.s3_data.bucket_id}/vector-index/index.json"
}

output "ingest_lambda_arn" {
  description = "ARN of the Ingest Lambda function."
  value       = module.lambda.ingest_function_arn
}

output "query_lambda_arn" {
  description = "ARN of the Query Lambda function."
  value       = module.lambda.query_function_arn
}
