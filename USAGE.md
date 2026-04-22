**USAGE**

**Quick Start**
- **Retrieve API URL**: run Terraform outputs in the environment folder (e.g. `environments/dev`) and set `API_URL` from the `api_endpoint` output.
- **Set env**: export `API_URL`, `DATA_BUCKET`, and `AWS_REGION` before running examples.

**Ingest — single product (API)**
- **Endpoint**: `POST ${API_URL}/products`
- **Example payload**:
```json
{
  "id": "PROD-001",
  "name": "Trail Runner Pro 5000",
  "category": "Footwear",
  "description": "The Trail Runner Pro 5000 is engineered for serious trail athletes who demand performance on technical terrain...",
  "price": 149.99,
  "attributes": {"color":"Slate Blue / Orange","material":"Gore-Tex / Mesh Upper","waterproof":true},
  "return_policy": "30-day returns in original unworn condition with original packaging."
}
```
- **curl**:
```bash
curl -X POST "${API_URL}/products" \
  -H "Content-Type: application/json" \
  -d '@single_product.json'
```

**Ingest — multiple products (API)**
- **Endpoint**: `POST ${API_URL}/products`
- **Example payload**: pass an array of product objects (use `data/products.json`).
- **curl**:
```bash
curl -X POST "${API_URL}/products" \
  -H "Content-Type: application/json" \
  -d '@data/products.json'
```

**Ingest — via S3 (upload file)**
- **Upload**:
```bash
aws s3 cp data/products.json s3://${DATA_BUCKET}/products.json --region ${AWS_REGION}
```
- The ingest Lambda is triggered by `s3:ObjectCreated` events and will read and index the JSON automatically.
- To simulate an S3 event when invoking the Lambda directly, use a payload like:
```json
{
  "Records": [
    {
      "eventSource": "aws:s3",
      "s3": {
        "bucket": {"name": "my-bucket-name"},
        "object": {"key": "products.json"}
      }
    }
  ]
}
```

**Query (chat)**
- **Endpoint**: `POST ${API_URL}/query`
- **Request payload**:
```json
{ "question": "Which waterproof hiking boots are available in size 9?" }
```
- **curl**:
```bash
curl -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{"question":"Which waterproof hiking boots are available in size 9?"}'
```
- **Response**: JSON with `answer` (string) and `sources` (array of product metadata).

**Getting Terraform outputs**
- From the environment folder (example `environments/dev`):
```bash
cd environments/dev
terraform init
terraform apply -auto-approve   # or terraform plan
terraform output -json
```
- Use `api_endpoint` for `API_URL` and `data_bucket_name` for `DATA_BUCKET`.

**References**
- Ingest logic: [lambdas/ingest/handler.py](lambdas/ingest/handler.py#L1-L400)
- Query logic: [lambdas/query/handler.py](lambdas/query/handler.py#L1-L400)
- Sample dataset: [data/products.json](data/products.json)

**Notes**
- The ingest Lambda accepts a single product object, an array of products, or an S3 event pointing to a JSON file.
- The query Lambda accepts `question` (also supports `query` or `q`) and returns `answer` and `sources`.
- Retrieval is still RAG: the query Lambda embeds the question, loads `vector-index/index.json` from S3, ranks chunks with numpy cosine similarity, and sends the top results to the LLM.
