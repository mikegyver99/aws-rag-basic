variable "prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "ingest_lambda_arn" {
  description = "ARN of the ingest lambda to integrate"
  type        = string
}

variable "query_lambda_arn" {
  description = "ARN of the query lambda to integrate"
  type        = string
}

variable "api_stage_name" {
  description = "API stage name"
  type        = string
  default     = "prod"
}
