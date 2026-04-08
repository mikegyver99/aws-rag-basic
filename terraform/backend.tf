/*
  Terraform S3 backend configuration template.

  Options:
  - Rename this file to `backend.tf` and fill the values below OR
  - Keep it as a template and run `terraform init` with `-backend-config` pointing
    to a config file or use CI to pass backend settings from secrets.

  Example (cli):
    terraform init \
      -backend-config="bucket=your-terraform-state-bucket" \
      -backend-config="key=path/to/state.tfstate" \
      -backend-config="region=us-east-1" \
      -backend-config="dynamodb_table=your-lock-table"

*/

terraform {
  backend "s3" {
    # Replace these placeholder values OR run `terraform init -backend-config=...`
    bucket         = "YOUR_TFSTATE_BUCKET"
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "YOUR_DYNAMODB_LOCK_TABLE"
    encrypt        = true
  }
}
