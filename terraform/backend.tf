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
    # Fill these values with the outputs from `bootstrap/` after running it.
    # Example bucket name produced by bootstrap: mikegyver99-aws-rag-basic-terraform-state-<ACCOUNT>-<REGION>
    bucket         = "mikegyver99-aws-rag-basic-terraform-state-<ACCOUNT>-<REGION>"
    key            = "aws-rag-basic/terraform.tfstate"
    region         = "<REGION>"
    # Example lock table: mikegyver99-aws-rag-basic-terraform-lock-<ACCOUNT>-<REGION>
    dynamodb_table = "mikegyver99-aws-rag-basic-terraform-lock-<ACCOUNT>-<REGION>"
    encrypt        = true
  }
}
