variable "prefix" {
  description = "Resource prefix"
  type        = string
}

variable "ingest_source_dir" {
  description = "Path to ingest lambda source"
  type        = string
}

variable "query_source_dir" {
  description = "Path to query lambda source"
  type        = string
}

variable "ingest_role_arn" {
  description = "IAM role ARN for ingest lambda"
  type        = string
}

variable "query_role_arn" {
  description = "IAM role ARN for query lambda"
  type        = string
}

variable "lambda_memory_mb" {
  type = number
}

variable "lambda_timeout_sec" {
  type = number
}

variable "common_lambda_env" {
  type = map(string)
}

variable "claude_model_id" {
  type = string
}

variable "enable_lambda_layer" {
  description = "Whether to publish and attach a Lambda layer with Python deps"
  type        = bool
  default     = true
}

variable "lambda_layer_name" {
  description = "Name to assign to the published Lambda Layer"
  type        = string
  # Do not reference other variables in a default value; leave blank to let
  # the module compute a sensible default based on `prefix`.
  default     = ""
}
