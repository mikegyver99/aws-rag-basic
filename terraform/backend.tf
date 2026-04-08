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
    # Replace <ACCOUNT> with your AWS account ID after running `bootstrap/`.
    # The bootstrap outputs include the concrete names; this file uses the
    # same naming pattern and pre-fills the default region from
    # `terraform/variables.tf` (us-east-1).
    bucket         = "mikegyver99-aws-rag-basic-terraform-state-<ACCOUNT>-us-east-1"
    key            = "aws-rag-basic/terraform.tfstate"
    region         = "us-east-1"
    # DynamoDB lock table follows the same pattern
    dynamodb_table = "mikegyver99-aws-rag-basic-terraform-lock-<ACCOUNT>-us-east-1"
    encrypt        = true
  }
}
