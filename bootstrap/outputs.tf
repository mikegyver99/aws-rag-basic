output "bucket_name" {
  description = "Name of the created S3 bucket for terraform state"
  value       = local.bucket_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for Terraform locking"
  value       = local.lock_table
}
