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

variable "enable_aoss_access" {
  description = "If true, attach an inline IAM policy granting AOSS actions to the Lambda roles (for debugging)."
  type        = bool
  default     = false
}
