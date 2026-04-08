# Bootstrap: create Terraform backend resources

This `bootstrap/` Terraform creates the S3 bucket and DynamoDB table used as the remote backend for the main `terraform/` configuration.

Usage (one-time):

```bash
cd bootstrap
terraform init
terraform apply
```

After this runs note the outputs `bucket_name` and `dynamodb_table_name` and use them to configure the backend for the main repository (either by replacing values in `terraform/backend.tf` or using `terraform init -backend-config=...`).

Notes:
- This configuration uses local state (default) so it can create the remote backend resources without a circular dependency.
- The resource names include your AWS account ID and region to keep them unique.
