"""
Query Lambda — handles user chat queries:

1. Receive a question via API Gateway POST /query
2. Embed the question using Bedrock Titan Embed Text v2
3. Run a k-NN search against OpenSearch Serverless (top-k chunks)
4. Build a prompt from the retrieved product chunks
5. Call Claude 3 Haiku on Bedrock for the answer
6. Return the answer JSON (or streamed) to the caller
"""

import json
import logging
import os

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Environment variables (set by Terraform)
# ---------------------------------------------------------------------------
OPENSEARCH_ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]
INDEX_NAME = os.environ.get("INDEX_NAME", "products")
EMBED_MODEL_ID = os.environ.get("EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0")
CLAUDE_MODEL_ID = os.environ.get("CLAUDE_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
TOP_K = int(os.environ.get("TOP_K", "5"))
REGION = os.environ.get("AWS_REGION", "us-west-2")

# ---------------------------------------------------------------------------
# AWS clients
# ---------------------------------------------------------------------------
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


def search(query_vector: list[float], k: int = TOP_K) -> list[dict]:
    """Run a k-NN search and return the top-k hit source documents."""
    query_body = {
        "size": k,
        "query": {
            "knn": {
                "embedding": {
                    "vector": query_vector,
                    "k": k,
                }
            }
        },
        "_source": {
            "excludes": ["embedding"]   # don't return the large vector in results
        },
    }
    response = opensearch_client.search(index=INDEX_NAME, body=query_body)
    hits = response.get("hits", {}).get("hits", [])
    return [hit["_source"] for hit in hits]


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
    user_message = (
        f"Here are the relevant products from our catalog:\n\n"
        f"{context}\n\n"
        f"Customer question: {question}"
    )

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "system": SYSTEM_PROMPT,
        "messages": [
            {
                "role": "user",
                "content": user_message,
            }
        ],
    }

    response = bedrock_runtime.invoke_model(
        modelId=CLAUDE_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(request_body),
    )

    result = json.loads(response["body"].read())
    # Claude Messages API returns content as a list of content blocks
    content_blocks = result.get("content", [])
    answer = " ".join(
        block.get("text", "") for block in content_blocks if block.get("type") == "text"
    )
    return answer.strip()


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
        logger.info("Retrieved %d chunks from OpenSearch", len(hits))

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
