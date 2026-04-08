variable "prefix" {
  type = string
}

variable "ui_bucket_arn" {
  type = string
}

variable "ui_bucket_domain_name" {
  description = "Regional domain name of the UI S3 bucket (e.g. my-bucket.s3.us-west-2.amazonaws.com)"
  type        = string
  default     = ""
}

variable "price_class" {
  type    = string
  default = "PriceClass_100"
}
