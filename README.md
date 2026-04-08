# aws-rag-basic
Repo for AWS RAG basic setup

## Terraform remote backend

This repository includes a `terraform/backend.tf` template. To enable a remote S3 backend for state and DynamoDB for locking, either:

- Rename and edit `terraform/backend.tf` with your real bucket/table names.
- Or run `terraform init` with `-backend-config` flags, or provide a backend config file such as `terraform/backend.conf.example`.

Example:

```bash
terraform init \
	-backend-config="bucket=your-terraform-state-bucket" \
	-backend-config="key=aws-rag-basic/terraform.tfstate" \
	-backend-config="region=us-east-1" \
	-backend-config="dynamodb_table=your-lock-table"
```

## GitHub Actions CI

A pair of workflows were added to `.github/workflows`:

- `terraform-plan.yml` — runs `terraform fmt` and `terraform plan` on `pull_request` and `push` to `main`. It also supports manual `workflow_dispatch`.
- `terraform-apply.yml` — a manual workflow (`workflow_dispatch`) that runs `terraform apply` only when the `approve` input is set to `yes`.

The workflows expect these repository secrets to be configured:

- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `TF_BACKEND_BUCKET`
- `TF_BACKEND_KEY` (e.g. `aws-rag-basic/terraform.tfstate`)
- `TF_BACKEND_REGION`
- `TF_BACKEND_DYNAMODB_TABLE`

Example: open the Actions tab in GitHub, run `Terraform Plan` from a pull request or run the `Terraform Apply (manual)` workflow and set `approve` to `yes` to deploy.

