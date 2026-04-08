This folder contains an example `dev` environment that calls the local modules.

Usage:

```bash
cd environments/dev
terraform init -backend-config=backend.conf
terraform plan
```

Notes:
- Replace `<ACCOUNT>` in `backend.conf` with the account id returned by the `bootstrap/` outputs.
- The `apigw` module currently expects lambda ARNs to be provided; update `ingest_lambda_arn` and `query_lambda_arn` or extend the module to create the lambdas.
