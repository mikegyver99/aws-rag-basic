variable "name" {
  description = "Bucket name (required)"
  type        = string
}

variable "force_destroy" {
  description = "Allow deleting non-empty bucket"
  type        = bool
  default     = false
}

variable "versioning" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "server_side_encryption" {
  description = "Enable SSE"
  type        = bool
  default     = true
}
