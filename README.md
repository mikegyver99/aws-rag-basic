## Project Summary

This project demonstrates a basic **Retrieval-Augmented Generation (RAG)** pipeline on AWS, provisioned entirely with Terraform. It showcases how to combine several AWS services to ingest documents, generate vector embeddings, store them for similarity search, and answer natural-language queries using a large language model.

**Key components:**

- **S3 vector index** — stores document embeddings as a JSON array in the data bucket; cosine similarity search runs in Lambda memory.
- **AWS Lambda (Ingest)** — reads documents from S3, generates embeddings via Amazon Bedrock, and appends them to the S3 vector index.
- **AWS Lambda (Query)** — accepts a user question, embeds it, loads the S3 vector index, retrieves the top-k similar chunks via cosine similarity, and calls an LLM on Bedrock to produce an answer.
- **Amazon Bedrock** — provides the embedding model and the LLM used for generation.
- **API Gateway (REST)** — exposes the ingest and query Lambdas as HTTP endpoints.
- **CloudFront + S3** — serves a simple static UI for interacting with the API.
- **Terraform modules** — reusable modules for API Gateway, CloudFront, IAM, Lambda, and S3, organized under `modules/`.
- **CI/CD** — GitHub Actions workflows for automated `terraform plan` and `apply`.

See [DIAGRAM.md](DIAGRAM.md) for the full architecture diagram.

## Bedrock Model Access Note

The default query path uses an Anthropic model through Amazon Bedrock. Anthropic requires a one-time use-case submission per AWS account before the model can be invoked.

If you see this during a query:

```json
{"error": "Internal error: An error occurred (ResourceNotFoundException) when calling the InvokeModel operation: Model use case details have not been submitted for this account. Fill out the Anthropic use case details form before using the model. If you have already filled out the form, try again in 15 minutes."}
```

go to the Bedrock console for the same AWS account and region, submit the Anthropic use-case details form, and retry after propagation completes. This is a one-time setup step per account.

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
cd environments/dev
export ACCOUNT=123456789012
envsubst < backend.conf > backend.rendered.conf
terraform init -backend-config=backend.rendered.conf
terraform validate
terraform plan -out=plan.tfplan
```
## Manual Actions
There are no required manual dependency-build steps for the current implementation.

If you previously built local files under `lambdas/layer/python`, remove them before the next deploy so Terraform does not package stale layer artifacts:

```bash
cd <repo root>
rm -rf lambdas/layer/python
```

### CI / backend rendering

The workflows automatically render `environments/dev/backend.conf` before running `terraform init`. They use `envsubst` to substitute the `${ACCOUNT}` placeholder from a secret named `AWS_ACCOUNT` in your repository or environment.

Required CI secrets for rendering and backend initialization:

- `AWS_ACCOUNT` — account identifier used in bucket/table names.

Notes and recommended workflow:

- Add `AWS_ACCOUNT` (or set it at org/repository level) so the backend config renders correctly.
- The pipeline installs `gettext-base` to provide `envsubst`; this is safe and small. If you prefer not to install packages, replace the rendering step with `sed` substitutions.
- Keep the S3 bucket and DynamoDB table created before switching to the remote backend; run the commands in the Bootstrapping section.
