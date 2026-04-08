variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "rag-basic"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "api_stage_name" {
  description = "API Gateway stage"
  type        = string
  default     = "dev"
}

variable "opensearch_collection_name" {
  description = "Name of the OpenSearch Serverless collection."
  type        = string
  default     = "products"
}

variable "opensearch_index_name" {
  description = "Name of the k-NN index inside the collection."
  type        = string
  default     = "products"
}

variable "embed_model_id" {
  description = "Bedrock model ID for text embeddings."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "claude_model_id" {
  description = "Bedrock model ID for answer generation."
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "lambda_memory_mb" {
  description = "Memory (MB) allocated to each Lambda function."
  type        = number
  default     = 512
}

variable "lambda_timeout_sec" {
  description = "Maximum execution time (seconds) for each Lambda function."
  type        = number
  default     = 60
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100 | PriceClass_200 | PriceClass_All)."
  type        = string
  default     = "PriceClass_100"
}

