resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ── Data / ingest bucket ───────────────────────────────────────────────────

resource "aws_s3_bucket" "data" {
  bucket        = "${local.prefix}-data-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Allow S3 to invoke the ingest Lambda
resource "aws_lambda_permission" "s3_invoke_ingest" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}

resource "aws_s3_bucket_notification" "ingest_trigger" {
  bucket     = aws_s3_bucket.data.id
  depends_on = [aws_lambda_permission.s3_invoke_ingest]

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }
}

# Upload the sample products.json on first deploy
resource "aws_s3_object" "sample_products" {
  bucket       = aws_s3_bucket.data.id
  key          = "products/products.json"
  source       = "${local.data_dir}/products.json"
  content_type = "application/json"
  etag         = filemd5("${local.data_dir}/products.json")
}

# ── UI / static website bucket ────────────────────────────────────────────

resource "aws_s3_bucket" "ui" {
  bucket        = "${local.prefix}-ui-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ui" {
  bucket = aws_s3_bucket.ui.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ui" {
  bucket = aws_s3_bucket.ui.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── OAC for CloudFront → UI bucket ────────────────────────────────────────

resource "aws_cloudfront_origin_access_control" "ui" {
  name                              = "${local.prefix}-ui-oac"
  description                       = "OAC for ${local.prefix} UI bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "ui_cloudfront" {
  bucket = aws_s3_bucket.ui.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipal"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.ui.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.ui.arn
        }
      }
    }]
  })
}

# Upload the chat UI index.html
resource "aws_s3_object" "ui_index" {
  bucket       = aws_s3_bucket.ui.id
  key          = "index.html"
  source       = "${path.root}/../ui/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.root}/../ui/index.html")
}
