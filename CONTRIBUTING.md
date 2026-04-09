# Contributing to aws-rag-basic

Thanks for wanting to contribute! The goal of this document is to make it easy to get started, keep contributions consistent, and ensure CI and state management are safe.

- **Code of conduct**: Be respectful. Keep discussions constructive.

- **Development branches**: Target `main` with pull requests. Use feature branches named `feat/<short-desc>` or `fix/<short-desc>`.

- **Formatting & linting**: Run `terraform fmt` before committing. Keep Terraform provider version consistent with repository workflows (see `.github/workflows`).

- **Terraform workflow**:
  - Use the environment folders under `environments/` (e.g. `environments/dev`) when developing.
  - Backend config is templated at `environments/dev/backend.conf` and is rendered by CI using the `AWS_ACCOUNT` secret.
  - If you change backend patterns, update CI workflows and `README.md`.

- **Bootstrapping remote backend**:
  - Create the S3 bucket and DynamoDB lock table before pointing Terraform at the remote backend. See the Bootstrapping section in `README.md`.
  - Use the `bootstrap/` folder or the `bootstrap` workflow to create these resources once (run locally with a local backend first).

- **Secrets & CI**:
  - Add `AWS_ACCOUNT` (account id or short identifier) to repository or org secrets so CI can render `backend.conf`.
  - Configure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` for CI runs.

- **Workflows**:
  - `terraform-plan.yml` runs `terraform fmt` and `terraform plan` and uploads the plan artifact.
  - `terraform-apply.yml` is manual and requires `approve: yes` to run.
  - Workflows render `environments/dev/backend.conf` using `envsubst` before `terraform init`.

- **Pull request checklist**:
  - Run `terraform fmt` and ensure no errors in `terraform plan` for the target env.
  - Update `README.md` or `CONTRIBUTING.md` if you change CI behavior, backend templates, or bootstrap flow.
  - Include a short description of the change and any manual steps required to test.

- **Testing changes**:
  - For infra changes, run `terraform plan` in the appropriate `environments/<env>` folder.
  - Use the `bootstrap/` workflow or scripts only for initial resource creation; avoid re-running bootstrap against production-like resources.

- **Adding modules or resources**:
  - Place reusable code in `modules/` and reference it from `environments/*`.
  - Follow existing variable naming conventions and make outputs explicit.

If you have questions about repository conventions or CI secrets, open an issue or mention the maintainers in your PR.