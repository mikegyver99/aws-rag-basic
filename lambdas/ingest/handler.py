"""
Ingest Lambda — handles two ingestion paths:

1. S3 path  — triggered by s3:ObjectCreated events on the data bucket.
              Reads the uploaded JSON file and ingests all products.
2. API path — triggered by API Gateway POST /products.
              Accepts a single product JSON body or a list of products.

Both paths converge on the same logic:
  parse  →  chunk description (~400 tokens)  →  Bedrock Titan Embed v2
  →  write vector + metadata to OpenSearch Serverless
"""

import json
import logging
import os
import re
import urllib.parse
import uuid

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Environment variables (set by Terraform)
# ---------------------------------------------------------------------------
OPENSEARCH_ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]  # e.g. https://xxx.us-east-1.aoss.amazonaws.com
INDEX_NAME = os.environ.get("INDEX_NAME", "products")
EMBED_MODEL_ID = os.environ.get("EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0")
CHUNK_SIZE = int(os.environ.get("CHUNK_SIZE", "400"))   # approximate tokens per chunk
REGION = os.environ.get("AWS_REGION", "us-east-1")
DATA_BUCKET = os.environ.get("DATA_BUCKET", "")

# ---------------------------------------------------------------------------
# AWS clients
# ---------------------------------------------------------------------------
s3_client = boto3.client("s3", region_name=REGION)
bedrock_runtime = boto3.client("bedrock-runtime", region_name=REGION)

credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    REGION,
    "aoss",
    session_token=credentials.token,
)

opensearch_client = OpenSearch(
    hosts=[OPENSEARCH_ENDPOINT],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=30,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _tokenise(text: str) -> list[str]:
    """
    Naïve whitespace tokeniser used only for chunk-size estimation.
    One word ≈ one token for English prose; Titan uses BPE so this is a
    conservative approximation (i.e. we may slightly under-fill chunks).
    """
    return re.split(r"\s+", text.strip())


def chunk_text(text: str, max_tokens: int = CHUNK_SIZE) -> list[str]:
    """Split *text* into chunks of at most *max_tokens* whitespace tokens."""
    words = _tokenise(text)
    chunks: list[str] = []
    current: list[str] = []
    for word in words:
        current.append(word)
        if len(current) >= max_tokens:
            chunks.append(" ".join(current))
            current = []
    if current:
        chunks.append(" ".join(current))
    return chunks or [text]


def embed(text: str) -> list[float]:
    """Call Bedrock Titan Embed Text v2 and return a 1536-dim vector."""
    body = json.dumps(
        {
            "inputText": text,
            "dimensions": 1536,
            "normalize": True,
        }
    )
    response = bedrock_runtime.invoke_model(
        modelId=EMBED_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=body,
    )
    result = json.loads(response["body"].read())
    return result["embedding"]


def ensure_index() -> None:
    """Create the k-NN index if it does not already exist."""
    if opensearch_client.indices.exists(index=INDEX_NAME):
        return
    index_body = {
        "settings": {
            "index": {
                "knn": True,
                "knn.algo_param.ef_search": 100,
            }
        },
        "mappings": {
            "properties": {
                "product_id":    {"type": "keyword"},
                "chunk_index":   {"type": "integer"},
                "chunk_text":    {"type": "text"},
                "embedding": {
                    "type": "knn_vector",
                    "dimension": 1536,
                    "method": {
                        "name": "hnsw",
                        "space_type": "cosinesimil",
                        "engine": "nmslib",
                        "parameters": {"ef_construction": 128, "m": 24},
                    },
                },
                "name":          {"type": "keyword"},
                "category":      {"type": "keyword"},
                "price":         {"type": "float"},
                "attributes":    {"type": "object", "enabled": True},
                "return_policy": {"type": "text"},
            }
        },
    }
    opensearch_client.indices.create(index=INDEX_NAME, body=index_body)
    logger.info("Created index %s", INDEX_NAME)


def ingest_product(product: dict) -> int:
    """Chunk, embed, and index a single product. Returns number of chunks written."""
    description = product.get("description", "")
    chunks = chunk_text(description)
    product_id = product.get("id", str(uuid.uuid4()))

    for idx, chunk in enumerate(chunks):
        vector = embed(chunk)
        doc = {
            "product_id":    product_id,
            "chunk_index":   idx,
            "chunk_text":    chunk,
            "embedding":     vector,
            "name":          product.get("name", ""),
            "category":      product.get("category", ""),
            "price":         product.get("price", 0.0),
            "attributes":    product.get("attributes", {}),
            "return_policy": product.get("return_policy", ""),
        }
        doc_id = f"{product_id}-chunk-{idx}"
        opensearch_client.index(index=INDEX_NAME, id=doc_id, body=doc)
        logger.debug("Indexed %s", doc_id)

    logger.info("Ingested product %s (%d chunks)", product_id, len(chunks))
    return len(chunks)


def load_products_from_s3(bucket: str, key: str) -> list[dict]:
    """Download and parse a JSON file from S3."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    raw = response["Body"].read().decode("utf-8")
    data = json.loads(raw)
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    raise ValueError(f"Unexpected JSON structure in s3://{bucket}/{key}")


# ---------------------------------------------------------------------------
# Lambda handler
# ---------------------------------------------------------------------------

def handler(event: dict, context) -> dict:  # noqa: ANN001
    """Lambda entry point."""
    ensure_index()

    products: list[dict] = []

    # --- S3 trigger ---
    if "Records" in event and event["Records"][0].get("eventSource") == "aws:s3":
        for record in event["Records"]:
            bucket = record["s3"]["bucket"]["name"]
            key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
            logger.info("S3 event: s3://%s/%s", bucket, key)
            products.extend(load_products_from_s3(bucket, key))

    # --- API Gateway trigger ---
    elif "body" in event:
        body_raw = event.get("body") or "{}"
        if event.get("isBase64Encoded", False):
            import base64
            body_raw = base64.b64decode(body_raw).decode("utf-8")
        body = json.loads(body_raw)
        if isinstance(body, list):
            products = body
        elif isinstance(body, dict):
            products = [body]
        else:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Request body must be a product object or array"}),
            }

    else:
        # Direct invocation with a list or a single product dict
        if isinstance(event, list):
            products = event
        elif isinstance(event, dict) and "id" in event:
            products = [event]
        else:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Unrecognised event format"}),
            }

    if not products:
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": "No products to ingest", "ingested": 0}),
        }

    total_products = 0
    total_chunks = 0
    errors: list[str] = []

    for product in products:
        try:
            chunks = ingest_product(product)
            total_products += 1
            total_chunks += chunks
        except Exception as exc:  # noqa: BLE001
            pid = product.get("id", "unknown")
            logger.error("Failed to ingest product %s: %s", pid, exc)
            errors.append(f"product {pid}: {exc}")

    result = {
        "ingested_products": total_products,
        "total_chunks": total_chunks,
    }
    if errors:
        result["errors"] = errors

    status = 207 if errors else 200
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(result),
    }
