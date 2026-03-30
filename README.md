# dual-backend-cache

**Node** (static text at `/`) and **Python** (`/time` with UTC server time) APIs exposed through **REST API Gateway** and **Lambda**. Function code is always packaged as **.zip**, uploaded to a **versioned S3 bucket**, and each Lambda references **bucket + key + `VersionId`**. There is **no ECR** or container-image deploy in this project.

The instructions below target **macOS**.

## Prerequisites (Mac)

| Tool | Purpose |
|------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | LocalStack |
| [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.5` | Provisioning |
| [Homebrew](https://brew.sh) (optional) | Install `terraform`, `awscli`, `node`, `python` |

```bash
brew install terraform awscli node python@3.11
```

- **Node.js** / **npm**: `terraform apply` runs `npm ci` in `node-app/` when building the zip.
- **Python 3** + **pip** (22+): packages the Python Lambda; on Mac Terraform uses **manylinux** wheels per `lambda_architecture` (avoids wrong `pydantic_core` on Lambda).

---

## Deploy flow (Terraform)

1. Produces `builds/node-lambda.zip` and `builds/python-lambda.zip` (local files + `data.archive_file`).
2. The **`lambda_artifacts_s3`** module creates the bucket (`bucket_prefix`), versioning, public access block, and uploads the zips (`packages/node/lambda.zip` and `packages/python/lambda.zip`).
3. Lambdas use `package_type = Zip`, `s3_bucket`, `s3_key`, `s3_object_version`, and `source_code_hash` (base64 SHA256 of the zip).

Useful outputs: `lambda_artifacts_bucket`, `lambda_artifacts_s3_keys`, `lambda_artifacts_s3_versions`.

---

## Architecture

### Runtime view

HTTP flow after deploy. Clients only talk to API Gateway; Lambdas read environment variables (route prefix, cache, stage). Traffic goes **browser/curl** → **REST API Gateway** → **Node Lambda** (Express) or **Python Lambda** (FastAPI + Mangum) by route (`/node`, `/python/time`, etc.).

In practice Lambda **loads the deployment package** from S3 at **deploy** time.

### Terraform-managed components

On the developer machine or in CI: code in `node-app` / `python-app` goes through `npm ci` and **manylinux** pip, produces `.zip` files (`archive_file`), and `terraform apply` uploads via **`lambda_artifacts_s3`** (bucket, versioning, objects). That bucket feeds **`lambda_container`** (IAM + Lambda functions), which integrates with **`http_api`** (REST API, routes, stage).

### Update flows: code vs infrastructure

| What changed | Where | What to run / what Terraform does |
|--------------|-------|-------------------------------------|
| Node or Python code | `node-app/`, `python-app/` | New zip → new `etag` / `VersionId` in S3 → `source_code_hash` changes → **Lambda function update** (same bucket/key). |
| Node dependencies | `package.json` / lock | `null_resource` runs `npm ci` → Node zip changes → same as above. |
| Python dependencies | `requirements-lambda.txt` | `null_resource` runs `pip` → Python zip changes → same as above. |
| Terraform build | `lambda_build.tf`, `archive_file` | Changes **how** the zip is built; next `apply` regenerates artifacts. |
| Fixed resources | `modules/lambda_container`, IAM, memory, timeout | **Terraform only**; no new app zip if code unchanged. |
| API Gateway | `modules/http_api`, paths, stage | **Terraform only**; new REST deployment when integrations change. |
| S3 bucket | `modules/lambda_artifacts_s3` | **Terraform only**; watch `force_destroy` in production. |
| App env vars | `CACHE_TTL_SEC`, `PATH_PREFIX`, etc. | **Terraform** updates Lambda environment → **no** new zip. |

Summary: **code** changes follow *edit → `terraform apply` → rebuild zip → new S3 object → Lambda on new version*; the **ideal CI** path is *Linux build → S3 upload → `terraform apply` referencing the artifact*; **infra-only** changes are *edit `.tf` / tfvars → `apply`* without a new app zip.

### Suggested improvements

1. **CI/CD pipeline (recommended) — two sequential phases**  
   Ideally **code** deploy separates **artifact publication** from **declarative** Lambda updates:

   **Phase 1 — versioned artifact in S3**  
   - **Linux** runner (`ubuntu-latest`): `npm ci` in `node-app`, Python bundle with **manylinux** pip, output `node-lambda.zip` and `python-lambda.zip`.  
   - Version id: **Git tag**, **commit SHA**, or **semver** in the **object key** (e.g. `packages/node/1.4.0/lambda.zip`) and/or rely on **bucket versioning** (each `PutObject` on the same key yields a new **`VersionId`**).  
   - `aws s3 cp` (or PutObject API) to the artifacts bucket with **OIDC** credentials (no long-lived access keys).

   **Phase 2 — Terraform immediately after**  
   - The same pipeline runs **`terraform plan`** / **`terraform apply`** (remote backend recommended: state in S3 + DynamoDB lock).  
   - Terraform must **reference** the package just published: e.g. **variables** `-var='node_s3_key=...'` / `version_id` from stage 1 output, or **`aws_s3_object` data source** for the latest version of a key, or a **generated `tfvars` file** from the upload job. Then `apply` updates **`s3_object_version`**, **`source_code_hash`** (hash of published zip), and Lambda config **in order** after upload — avoiding races between “object not there yet” and “Lambda already points”.

   **Gates**: `terraform plan` on PR (read-only); **`apply` only on `main`** or after manual approval, after Phase 1 succeeds.

   **Note for this repo**: Terraform still **builds** zips on `apply`. To match the ideal flow, move build to the pipeline (Phase 1) and teach the S3/Lambda modules to accept **key + version_id + hash** from variables or data sources. Target: **CI** checkout → **build** (`npm ci`, manylinux pip, zips) → **S3** `PutObject` (new key or new `VersionId`) → artifacts passed to next job → **Terraform** with OIDC applies and updates Node/Python Lambdas with S3 key, version, and `source_code_hash`.

2. **Split “base infra” from “code only”** (optional, faster deploys)  
   - Terraform creates bucket, Lambdas empty or first version.  
   - Later pipelines use only **`aws lambda update-function-code`** + S3 upload (optional version / weighted alias for canary). Requires discipline so Terraform state and live code stay aligned (document or use `terraform apply -target` carefully).

3. **State and environments**  
   - Remote backend for state; **workspaces** or `env/dev`, `env/prod` folders with separate `tfvars`.  
   - `lambda_artifacts_bucket_force_destroy = false` in production.

4. **Quality before deploy**  
   - `npm test` / `pytest`, linter, dependency scanning in the same pipeline that builds the zip.

5. **Observability**  
   - Lambda log groups already exist; add CloudWatch alarms (errors, duration) and optionally X-Ray.

6. **New Relic on Lambdas (layer + extension)**  
   - New Relic **Lambda layers** bundle the **agent** (Node or Python), a **handler wrapper**, and the **extension** that ships telemetry without you running a separate process.  
   - **Real AWS**: attach the layer for your **region**, **architecture** (`x86_64` / `arm64`), and **runtime** (e.g. Node 18/20, Python 3.11). ARN catalog: [layers.newrelic-external.com](https://layers.newrelic-external.com/). Docs: [Install and configure Lambda monitoring](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/instrument-lambda-function/configure-serverless-aws-monitoring/) and [environment variables](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/instrument-lambda-function/env-variables-lambda/).  
   - **Terraform**: in `lambda_container`, add `layers = [layer_arn]` and set the **handler** to the layer’s (`newrelic-lambda-wrapper.handler` for Node, `newrelic_lambda_wrapper.handler` for Python), with the real handler in `NEW_RELIC_LAMBDA_HANDLER` (e.g. `lambda.handler`, `handler.handler`). Set `NEW_RELIC_LICENSE_KEY`, `NEW_RELIC_ACCOUNT_ID`, `NEW_RELIC_TRUSTED_ACCOUNT_KEY`, `NEW_RELIC_LAMBDA_HANDLER`, `NEW_RELIC_APM_LAMBDA_MODE=true`, `NEW_RELIC_LAMBDA_EXTENSION_ENABLED=true`, etc.  
   - **Node with ESM** (`"type": "module"`): follow New Relic docs for ESM loader / handler; you may need `NODE_OPTIONS` or agent-specific variables.  
   - **LocalStack**: official New Relic layers target AWS; local emulators usually do not support this end-to-end — treat as **real AWS** improvement.  
   - **Production**: prefer **Secrets Manager** (`NEW_RELIC_LICENSE_KEY_SECRET`) over a plain license key in `tfvars`/state.

7. **Secrets**  
   - No secrets in the zip; use **SSM Parameter Store** / **Secrets Manager** + Lambda role permissions when needed.

---

## Terraform variables (summary)

| Variable | LocalStack (typical) | Real AWS (typical) |
|----------|----------------------|---------------------|
| `use_localstack` | `true` | `false` |
| `localstack_endpoint` | `http://127.0.0.1:4566` | (ignored) |
| `aws_region` | e.g. `us-east-1` | Desired region |
| `lambda_artifacts_bucket_force_destroy` | `true` (easier destroy in dev) | `false` in prod to protect the bucket |
| `lambda_architecture` | `x86_64` or `arm64` | Must match function |
| `lambda_runtime_node_zip` | `nodejs18.x` (LocalStack often rejects `nodejs22.x`) | e.g. `nodejs20.x` if supported |
| `lambda_runtime_python_zip` | `python3.11` | Adjust per region |
| `cache_ttl_seconds_node` / `cache_ttl_seconds_python` | Default 10 / 60 | Optional |
| `alb_route_node` / `alb_route_python` | `/node`, `/python` | Optional |
| `api_gateway_stage_name` | `dev` | Optional |

Credentials:

- **LocalStack**: provider uses `test` / `test` when `use_localstack = true`.
- **AWS**: `AWS_PROFILE`, `~/.aws/credentials`, etc.

---

## Run locally with LocalStack

### 1. Start LocalStack

`docker-compose` enables **S3** along with Lambda, IAM, API Gateway, etc.

```bash
cd /path/to/dual-backend-cache
docker compose up -d localstack
```

Use **`http://127.0.0.1:4566`** (avoids `localhost` → `::1` and connection issues on Mac).

### 2. Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Minimal `terraform.tfvars`:

```hcl
use_localstack      = true
localstack_endpoint = "http://127.0.0.1:4566"
aws_region          = "us-east-1"
```

### 3. Apply

```bash
terraform init
terraform apply
```

First apply needs **network** (npm/pip).

### 4. Test the API

```text
http://127.0.0.1:4566/restapis/<api-id>/<stage>/_user_request_<path>
```

```bash
curl -sS "$(terraform output -raw example_url_node_static)"
curl -sS "$(terraform output -raw example_url_python_time)"
```

### 5. Local apps (Compose, without LocalStack)

```bash
docker compose up -d node-api python-api
```

- Node: `http://127.0.0.1:3000/`
- Python: `http://127.0.0.1:3001/time`

---

## Provision on AWS

```bash
aws configure
# or
export AWS_PROFILE=your-profile
```

`terraform.tfvars`:

```hcl
use_localstack = false
aws_region     = "us-east-1"
# Recommended in production:
# lambda_artifacts_bucket_force_destroy = false
```

```bash
cd terraform
terraform init
terraform apply
```

Invoke using `terraform output http_api_invoke_url_aws_format` and paths `/node`, `/python/time`, etc.

---

## Troubleshooting (Mac / LocalStack)

| Issue | Suggestion |
|-------|------------|
| Terraform cannot reach LocalStack | `localstack_endpoint = "http://127.0.0.1:4566"` |
| Invalid Lambda runtime | `lambda_runtime_node_zip = "nodejs18.x"`, `lambda_runtime_python_zip = "python3.11"` |
| `pydantic_core` on Python Lambda | Apply with network; check `lambda_architecture` and recent pip |
| Odd LocalStack state | `docker compose down -v` and apply again |

---

## Useful layout

- `node-app/` — Express + `lambda.js`
- `python-app/` — FastAPI + `handler.py` (Mangum)
- `terraform/lambda_build.tf` — zip build
- `terraform/modules/lambda_artifacts_s3/` — S3 bucket + versioning + `.zip` objects
- `terraform/modules/lambda_container/` — IAM + Lambda (code from S3)
- `terraform/modules/http_api/` — REST API Gateway
- `docker-compose.yml` — LocalStack + optional `node-api` / `python-api`
