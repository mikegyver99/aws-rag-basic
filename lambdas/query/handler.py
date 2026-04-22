"""
Query Lambda — handles user chat queries:

1. Receive a question via API Gateway POST /query
2. Embed the question using Bedrock Titan Embed Text v2
3. Run cosine similarity search against the S3 vector index (top-k chunks)
4. Build a prompt from the retrieved product chunks
5. Call Claude 3 Haiku on Bedrock for the answer
6. Return the answer JSON to the caller
"""

import json
import logging
import os

import boto3
import numpy as np

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Environment variables (set by Terraform)
# ---------------------------------------------------------------------------
INDEX_BUCKET    = os.environ["INDEX_BUCKET"]
INDEX_KEY       = os.environ.get("INDEX_KEY", "vector-index/index.json")
EMBED_MODEL_ID  = os.environ.get("EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0")
CLAUDE_MODEL_ID = os.environ.get("CLAUDE_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
TOP_K           = int(os.environ.get("TOP_K", "5"))
REGION          = os.environ.get("AWS_REGION", "us-west-2")

# ---------------------------------------------------------------------------
# AWS clients
# ---------------------------------------------------------------------------
s3_client       = boto3.client("s3", region_name=REGION)
bedrock_runtime = boto3.client("bedrock-runtime", region_name=REGION)

# System prompt template
SYSTEM_PROMPT = (
    "You are a helpful outdoor and sports product assistant. "
    "Answer the customer's question using ONLY the product information provided. "
    "If the answer cannot be found in the provided product information, say so honestly. "
    "Be concise and helpful. When relevant, mention product names, prices, and key features."
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def embed(text: str) -> list[float]:
    """Call Bedrock Titan Embed Text v2 and return a 1024-dim vector."""
    body = json.dumps({
        "inputText": text,
        "dimensions": 1024,
        "normalize": True,
    })
    response = bedrock_runtime.invoke_model(
        modelId=EMBED_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=body,
    )
    result = json.loads(response["body"].read())
    return result["embedding"]


def search(query_vector: list[float], k: int = TOP_K) -> list[dict]:
    """Load the S3 vector index and return the top-k most similar chunks."""
    try:
        obj = s3_client.get_object(Bucket=INDEX_BUCKET, Key=INDEX_KEY)
        index = json.loads(obj["Body"].read().decode("utf-8"))
    except s3_client.exceptions.NoSuchKey:
        logger.warning("Vector index not found at s3://%s/%s", INDEX_BUCKET, INDEX_KEY)
        return []

    if not index:
        return []

    # Vectors are L2-normalised (Titan normalize=True), so dot product == cosine similarity.
    vectors = np.array([entry["embedding"] for entry in index], dtype=np.float32)
    q = np.array(query_vector, dtype=np.float32)
    scores = vectors @ q                       # shape: (n,)
    top_indices = np.argsort(scores)[::-1][:k]
    return [{key: val for key, val in index[i].items() if key != "embedding"} for i in top_indices]


def build_context(hits: list[dict]) -> str:
    """Format retrieved chunks into a human-readable context block."""
    if not hits:
        return "No relevant products found."

    sections = []
    for i, hit in enumerate(hits, start=1):
        name = hit.get("name", "Unknown Product")
        category = hit.get("category", "")
        price = hit.get("price", 0.0)
        attributes = hit.get("attributes", {})
        return_policy = hit.get("return_policy", "")
        chunk_text = hit.get("chunk_text", "")

        attr_lines = ", ".join(
            f"{k}: {v}" for k, v in attributes.items() if v is not None
        )

        section = (
            f"Product {i}: {name}\n"
            f"  Category: {category}\n"
            f"  Price: ${price:.2f}\n"
            f"  Attributes: {attr_lines}\n"
            f"  Description excerpt: {chunk_text}\n"
            f"  Return policy: {return_policy}"
        )
        sections.append(section)

    return "\n\n".join(sections)


def call_claude(question: str, context: str) -> str:
    """Call Claude 3 Haiku via Bedrock Messages API and return the answer text."""
    # Build a single prompt by combining system instructions, retrieved context,
    # and the user's question. Using the simpler `input` format avoids
    # schema-matching issues with the Bedrock Messages schema variations.
    prompt = (
        SYSTEM_PROMPT + "\n\n"
        + "Here are the relevant products from our catalog:\n\n"
        + context
        + "\n\nCustomer question: "
        + question
    )

    # Choose request schema based on model type. Anthropic models expect a
    # `messages` array with a top-level `system` field; other text models
    # commonly accept a single `input`.
    if CLAUDE_MODEL_ID.startswith("anthropic."):
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "system": SYSTEM_PROMPT,
            "messages": [
                {
                    "role": "user",
                    "content": "Here are the relevant products from our catalog:\n\n" + context + "\n\nCustomer question: " + question,
                },
            ],
        }
    else:
        request_body = {
            "input": prompt,
            "maxTokens": 1024,
            "temperature": 0.0,
        }

    response = bedrock_runtime.invoke_model(
        modelId=CLAUDE_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(request_body),
    )

    result = json.loads(response["body"].read())
    # Many Bedrock text models return the generated text in `output` or `body`.
    # Attempt to extract common fields safely.
    if isinstance(result, dict):
        # Common field used by the text API
        if "output" in result and isinstance(result["output"], str):
            return result["output"].strip()
        # Some models return a top-level `body` string
        if "body" in result and isinstance(result["body"], str):
            return result["body"].strip()
        # Fallback: join any text blocks in `content`
        content_blocks = result.get("content", [])
        answer = " ".join(
            block.get("text", "") for block in content_blocks if block.get("type") == "text"
        )
        return answer.strip()

    return ""


# ---------------------------------------------------------------------------
# Lambda handler
# ---------------------------------------------------------------------------

def handler(event: dict, context) -> dict:  # noqa: ANN001
    """Lambda entry point."""
    # Parse question from API Gateway body
    if "body" in event:
        body_raw = event.get("body") or "{}"
        if event.get("isBase64Encoded", False):
            import base64
            body_raw = base64.b64decode(body_raw).decode("utf-8")
        body = json.loads(body_raw)
    elif isinstance(event, dict):
        body = event
    else:
        return _error(400, "Unrecognised event format")

    question = body.get("question") or body.get("query") or body.get("q")
    if not question:
        return _error(400, "Missing required field: 'question'")

    question = question.strip()
    if len(question) > 2000:
        return _error(400, "Question exceeds 2000 character limit")

    try:
        # 1. Embed the question
        logger.info("Embedding question: %s", question[:100])
        query_vector = embed(question)

        # 2. Retrieve top-k chunks
        hits = search(query_vector)
        logger.info("Retrieved %d chunks from S3 index", len(hits))

        # 3. Build context
        context_text = build_context(hits)

        # 4. Call Claude
        answer = call_claude(question, context_text)
        logger.info("Claude answer length: %d chars", len(answer))

        # 5. Return response
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": json.dumps(
                {
                    "answer": answer,
                    "sources": [
                        {
                            "product_id": h.get("product_id"),
                            "name": h.get("name"),
                            "category": h.get("category"),
                            "price": h.get("price"),
                        }
                        for h in hits
                    ],
                }
            ),
        }

    except Exception as exc:  # noqa: BLE001
        logger.error("Query failed: %s", exc, exc_info=True)
        return _error(500, f"Internal error: {exc}")


def _error(status: int, message: str) -> dict:
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({"error": message}),
    }
