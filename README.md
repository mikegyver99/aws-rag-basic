## Project Summary

This project demonstrates a basic **Retrieval-Augmented Generation (RAG)** pipeline on AWS, provisioned entirely with Terraform. It showcases how to combine several AWS services to ingest documents, generate vector embeddings, store them for similarity search, and answer natural-language queries using a large language model.

**Key components:**

- Either **Amazon OpenSearch Serverless (AOSS)** — vector store for k-NN similarity search over document embeddings. ($$$)
- OR **S3 vector index** — stores document embeddings as a JSON array in the data bucket; cosine similarity search runs in Lambda memory. ($)
- **AWS Lambda (Ingest)** — reads documents from S3, generates embeddings via Amazon Bedrock, and indexes them into OpenSearch.
- **AWS Lambda (Query)** — accepts a user question, embeds it, retrieves relevant documents from OpenSearch, and calls an LLM on Bedrock to produce an answer.
- **Amazon Bedrock** — provides the embedding model and the LLM used for generation.
- **API Gateway (REST)** — exposes the ingest and query Lambdas as HTTP endpoints.
- **CloudFront + S3** — serves a simple static UI for interacting with the API.
- **Terraform modules** — reusable modules for API Gateway, CloudFront, IAM, Lambda, OpenSearch, and S3, organized under `modules/`.
- **CI/CD** — GitHub Actions workflows for automated `terraform plan` and `apply`.

See Branches for the various setups/diagrams.
