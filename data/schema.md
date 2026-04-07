# Product Data Schema

This document describes the data model used for the outdoor/sports product catalog.

## Product Record

Each product is stored as a JSON object with the following fields:

| Field            | Type     | Required | Description                                                       |
|------------------|----------|----------|-------------------------------------------------------------------|
| `id`             | string   | ✅       | Unique product identifier (e.g. `"PROD-001"`)                    |
| `name`           | string   | ✅       | Human-readable product name                                       |
| `category`       | string   | ✅       | Top-level category (e.g. `"Footwear"`, `"Camping"`, `"Apparel"`) |
| `description`    | string   | ✅       | Full product description — the primary text used for embeddings   |
| `price`          | number   | ✅       | Retail price in USD (two decimal places)                          |
| `attributes`     | object   | ✅       | Structured key/value product attributes (see below)               |
| `return_policy`  | string   | ✅       | Plain-text return/exchange policy for this product                |

### `attributes` Object

The `attributes` object is flexible; any of the following keys may be present depending on the product category:

| Key           | Type    | Example values                                   |
|---------------|---------|--------------------------------------------------|
| `color`       | string  | `"Navy Blue"`, `"Forest Green"`, `"Black"`       |
| `material`    | string  | `"Gore-Tex"`, `"Merino Wool"`, `"Nylon"`         |
| `waterproof`  | boolean | `true`, `false`                                  |
| `weight_oz`   | number  | `12.5`, `32.0`                                   |
| `gender`      | string  | `"Men's"`, `"Women's"`, `"Unisex"`               |
| `sizes`       | array   | `["XS","S","M","L","XL"]`                        |
| `fit`         | string  | `"Slim"`, `"Regular"`, `"Relaxed"`               |
| `insulation`  | string  | `"Down 800-fill"`, `"Synthetic"`, `"Fleece"`     |
| `capacity_L`  | number  | `20`, `45`, `70`                                 |
| `frame`       | string  | `"Internal"`, `"External"`, `"Frameless"`        |
| `seasons`     | array   | `["3-season"]`, `["4-season","winter"]`          |
| `pole_count`  | number  | `1`, `2`                                         |
| `temp_rating` | string  | `"20°F"`, `"-10°F"`                              |
| `lumens`      | number  | `200`, `400`, `1000`                             |
| `runtime_h`   | number  | `8`, `40`                                        |
| `length_ft`   | number  | `6.5`, `7.0`                                     |
| `r_value`     | number  | `2.2`, `5.7`                                     |
| `sport`       | string  | `"Hiking"`, `"Cycling"`, `"Paddling"`            |
| `terrain`     | string  | `"Trail"`, `"Road"`, `"Whitewater"`              |

## OpenSearch Document Structure

Each product is split into one or more **chunks** before indexing. The chunk
boundaries follow the `description` field (~400 tokens per chunk). All other
fields are stored as metadata alongside every chunk.

```json
{
  "product_id":    "PROD-001",
  "chunk_index":   0,
  "chunk_text":    "<~400-token slice of the description>",
  "embedding":     [0.012, -0.034, ...],   // 1536-dim Bedrock Titan Embed v2
  "name":          "Trail Runner Pro 5000",
  "category":      "Footwear",
  "price":         129.99,
  "attributes":    { "color": "Navy Blue", "waterproof": true, ... },
  "return_policy": "30-day returns in original condition."
}
```

## Ingestion Flow

```
products.json (or POST /products)
        │
        ▼
  Ingest Lambda
        │  parse JSON records
        │  chunk description (~400 tokens)
        │  Bedrock Titan Embed v2  →  1536-dim vector
        │
        ▼
  OpenSearch Serverless
  (k-NN index, cosine similarity)
```

## Query Flow

```
User question (chat UI)
        │
        ▼
  Query Lambda
        │  Bedrock Titan Embed v2  →  question vector
        │  k-NN search (top 5 chunks)
        │  build prompt: system + context chunks + question
        │  Claude 3 Haiku (Bedrock)  →  answer
        │
        ▼
  Chat UI
```
