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

variable "ingest_lambda_invoke_arn" {
  description = "API Gateway integration URI (lambda invoke ARN) for ingest"
  type        = string
  default     = ""
}

variable "query_lambda_invoke_arn" {
  description = "API Gateway integration URI (lambda invoke ARN) for query"
  type        = string
  default     = ""
}

variable "cloudwatch_role_arn" {
  description = "Optional ARN of the IAM role API Gateway will assume to write CloudWatch logs"
  type        = string
  default     = ""
}

variable "api_stage_name" {
  description = "API stage name"
  type        = string
  default     = "prod"
}
