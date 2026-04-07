variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short slug used as a prefix for every resource name."
  type        = string
  default     = "rag-basic"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)."
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

variable "top_k" {
  description = "Number of nearest-neighbour chunks returned per query."
  type        = number
  default     = 5
}

variable "chunk_size_tokens" {
  description = "Approximate token count per description chunk."
  type        = number
  default     = 400
}

variable "api_stage_name" {
  description = "API Gateway deployment stage name."
  type        = string
  default     = "prod"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100 | PriceClass_200 | PriceClass_All)."
  type        = string
  default     = "PriceClass_100"
}
