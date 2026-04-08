provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_region = "${data.aws_caller_identity.current.account_id}-${var.region}"
  bucket_name    = "mikegyver99-aws-rag-basic-terraform-state-${local.account_region}"
  lock_table     = "mikegyver99-aws-rag-basic-terraform-lock-${local.account_region}"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "terraform-state"
  }
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_block" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
