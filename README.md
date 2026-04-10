# aws-rag-basic
Repo for AWS RAG basic setup
## OpenSearch Serverless (AOSS) — billing note

- Deploying the OpenSearch Serverless collection (`module.opensearch`) provisions managed compute and storage that is billed while the collection exists. Even idle collections can incur hourly charges (a small collection for a few hours can cost a couple dollars).

- To remove the collection and stop charges quickly, run from the environment folder:

```bash
cd environments/dev
# Destroy only the OpenSearch collection/module
terraform destroy -target=module.opensearch

# Or destroy the entire environment (removes all resources)
terraform destroy
```

- Recommendation: destroy test/dev collections when idle, or create/destroy them on demand. Use AWS Cost Explorer and billing alerts to track unexpected charges.

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

You can bootstrap resources with Terraform by creating a small configuration that creates the S3 bucket and DynamoDB table. Run that once (with a local backend) to create the resources, then re-run `terraform init` in `environments/dev` with the remote backend configured.

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
## Manual Actions (Will be done by CI/CD but manual step for POC)
```
cd <repo root>
echo "Building Python deps into layer/ and zipping layer..."
python3 -m pip install --upgrade pip
mkdir -p modules/lambda/.build/python
python3 -m pip install -r lambdas/ingest/requirements.txt -t modules/lambda/.build/python
pushd modules/lambda/.build
zip -r layer.zip python
rm -rf python
popd
```
Commit layer.zip file.  

### CI / backend rendering

The workflows automatically render `environments/dev/backend.conf` before running `terraform init`. They use `envsubst` to substitute the `${ACCOUNT}` placeholder from a secret named `AWS_ACCOUNT` in your repository or environment.

Required CI secrets for rendering and backend initialization:

- `AWS_ACCOUNT` — account identifier used in bucket/table names.

Notes and recommended workflow:

- Add `AWS_ACCOUNT` (or set it at org/repository level) so the backend config renders correctly.
- The pipeline installs `gettext-base` to provide `envsubst`; this is safe and small. If you prefer not to install packages, replace the rendering step with `sed` substitutions.
- Keep the S3 bucket and DynamoDB table created before switching to the remote backend; run the commands in the Bootstrapping section.
