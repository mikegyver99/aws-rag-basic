# aws-rag-basic
Repo for AWS RAG basic setup

### Bootstrapping the S3 state bucket and DynamoDB lock table

Before running `terraform init` with a remote backend you must create the S3 bucket and the DynamoDB table used for locking. You can create them manually, with the AWS CLI, or with a small Terraform/bootstrap script. Below are recommended AWS CLI commands.

- Create an S3 bucket (adjust `--region` and `--create-bucket-configuration` as needed):

```bash
aws s3api create-bucket \
  --bucket YOUR_BUCKET_NAME-REGION-an \
  --bucket-namespace account-regional \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2 \
  --profile <myprofile>


# Recommended: enable versioning
aws s3api put-bucket-versioning --bucket YOUR_BUCKET_NAME-REGION-an --versioning-configuration Status=Enabled

# Recommended: enable default server-side encryption (SSE-S3)
aws s3api put-bucket-encryption --bucket YOUR_BUCKET_NAME-REGION-an \
	--server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

- Create a DynamoDB table for Terraform state locking (primary key `LockID`):

```bash
aws dynamodb create-table \
	--table-name YOUR_LOCK_TABLE \
	--attribute-definitions AttributeName=LockID,AttributeType=S \
	--key-schema AttributeName=LockID,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

Notes:
- Replace `YOUR_BUCKET_NAME-REGION-an` and `YOUR_LOCK_TABLE` with your chosen names.
- Ensure the IAM identity you use for Terraform has permissions to read/write the S3 bucket and to put/get/delete items in the DynamoDB table.
- Enable bucket versioning and server-side encryption for safer state handling.

If you prefer to bootstrap resources using Terraform, you can add a small bootstrap configuration (see the `bootstrap/` folder) that creates the S3 bucket and DynamoDB table. Run that once (with a local backend) to create the resources, then re-run `terraform init` in `environments/dev` with the remote backend configured.

## Terraform remote backend

Terraform configuration has been organized into environment-specific folders and reusable modules. Use the `environments/dev` folder to work with the development environment and the `modules` directory for shared modules.

The backend configuration for `dev` lives at `environments/dev/backend.conf`. To enable a remote S3 backend for state and a DynamoDB table for locking you can either:

- Edit `environments/dev/backend.conf` with your real bucket/table names.
- Or run `terraform init` from the environment folder and pass `-backend-config` flags.

Example (from `environments/dev`):

```bash
terraform init \
	-backend-config="bucket=your-terraform-state-bucket" \
	-backend-config="key=aws-rag-basic/environments/dev/terraform.tfstate" \
	-backend-config="region=us-west-2" \
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
- `TF_BACKEND_KEY` (e.g. `aws-rag-basic/environments/dev/terraform.tfstate`)
- `TF_BACKEND_REGION`
- `TF_BACKEND_DYNAMODB_TABLE`
- `AWS_ACCOUNT`

Example: open the Actions tab in GitHub, run `Terraform Plan` from a pull request or run the `Terraform Apply (manual)` workflow and set `approve` to `yes` to deploy.

### CI / backend rendering

The workflows automatically render `environments/dev/backend.conf` before running `terraform init`. They use `envsubst` to substitute the `${ACCOUNT}` placeholder from a secret named `AWS_ACCOUNT` in your repository or environment.

Required CI secrets for rendering and backend initialization:

- `AWS_ACCOUNT` — account identifier used in bucket/table names.
- `TF_BACKEND_BUCKET`, `TF_BACKEND_REGION`, `TF_BACKEND_DYNAMODB_TABLE` — optional; when present they are used by workflows or can be left blank if using the rendered backend file.

Notes and recommended workflow:

- Add `AWS_ACCOUNT` (or set it at org/repository level) so the backend config renders correctly.
- The pipeline installs `gettext-base` to provide `envsubst`; this is safe and small. If you prefer not to install packages, replace the rendering step with `sed` substitutions.
- Keep the bootstrap resources (S3 bucket and DynamoDB table) created before switching to the remote backend. Use the `bootstrap/` workflow or run the commands in the Bootstrapping section.

