resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.prefix}-enc"
  type        = "encryption"
  description = "Encryption policy for ${var.collection_name}"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.collection_name}"]
    }]
    AWSOwnedKey = true
  })
}

locals {
  network_rules = [
    {
      ResourceType = "collection"
      Resource     = ["collection/${var.collection_name}"]
    },
    {
      ResourceType = "dashboard"
      Resource     = ["collection/${var.collection_name}"]
    }
  ]
  public_policy = {
    Description     = "Public access to collection and Dashboards endpoint for ${var.collection_name}"
    Rules           = local.network_rules
    AllowFromPublic = true
    SourceVPCEs     = []
  }

  vpce_policy = merge(local.public_policy, {
    Description     = "VPC access to collection and Dashboards endpoint for ${var.collection_name}"
    AllowFromPublic = false
    SourceVPCEs     = var.source_vpce_ids
  })

  network_policy = length(var.source_vpce_ids) > 0 ? local.vpce_policy : local.public_policy
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.prefix}-net"
  type        = "network"
  description = "Network policy for ${var.collection_name}"
  policy = jsonencode([local.network_policy])
}

# Optional access policy granting specific IAM principals access to the collection
locals {
  access_policy = {
    Description = "Access policy for ${var.collection_name}"
    Rules       = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
      }
    ]
    Principal = {
      AWS = var.access_principal_arns
    }
  }
}

## NOTE: OpenSearch Serverless 'access' policy type is not supported
## by the Terraform AWS provider in some versions. If you need to
## create an access policy that grants IAM principals access to the
## collection, you can either:
##  - Upgrade the AWS provider to a version that supports 'access' policies,
##  - Or create the access policy using the AWS CLI after Terraform apply.

## The module accepts `access_principal_arns` but does not currently
## create the access policy resource to maintain compatibility with
## provider versions that lack support.

resource "aws_opensearchserverless_collection" "products" {
  name        = var.collection_name
  type        = "VECTORSEARCH"
  description = "k-NN product catalog vector store"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

resource "aws_opensearchserverless_access_policy" "data" {
  name = "${var.prefix}-access"
  type = "data"

  policy = jsonencode([
    {
      Description = "Data access for ${var.collection_name}"
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.collection_name}/*"]
          Permission   = ["aoss:*"]
        }
      ]
      Principal = var.access_principal_arns
    }
  ])
}

output "collection_endpoint" {
  value = aws_opensearchserverless_collection.products.collection_endpoint
}

output "collection_arn" {
  value = aws_opensearchserverless_collection.products.arn
}
