variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "embed_model_id" {
  type = string
  default = ""
}

variable "claude_model_id" {
  type = string
  default = ""
}

variable "index_bucket_arn" {
  description = "ARN of the S3 bucket used as the vector index store. Grants Lambdas GetObject/PutObject when set."
  type        = string
  default     = ""
}

variable "enable_bedrock_access" {
  description = "If true, attach an inline IAM policy allowing the Lambdas to call Bedrock InvokeModel."
  type        = bool
  default     = false
}
