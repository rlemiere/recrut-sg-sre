# TODO

Things that should be improved but did not fit in the initial time frame.

---

## Infrastructure (Terraform)

### CI: Terraform linting and formatting (`terraform fmt` + `terraform validate` + `tflint`)

Currently there is no IaC linting in the CI pipeline. Without it, style drift accumulates silently and provider-level configuration errors (unknown arguments, deprecated attributes, wrong resource types) are only caught at `terraform apply` time - after the plan has already been reviewed and approved. Adding `terraform fmt -check -recursive`, `terraform validate`, and `tflint` as early CI gates ensures problems are flagged on every push, before they reach the infra.

### CI: Trivy scanning for Terraform (IaC misconfiguration detection)

Trivy can scan Terraform files for cloud misconfigurations (open ingress CIDR blocks, missing encryption at rest, publicly accessible resources, overly permissive IAM policies). Right now, a misconfiguration like an open security group or an unencrypted S3 bucket would reach the AWS account undetected. Adding a Trivy IaC scan step in the CI pipeline catches these for free, before any `terraform apply` runs.

### Refactor: Move security groups into a dedicated module

`backend.tf` contains 10 explicit `aws_security_group` and `aws_vpc_security_group_*_rule` resources written outside any module. Every other resource in the project (VPC, ECS, ALB, RDS, S3, CloudFront, ACM) uses an official AWS module. Having security groups as bare resources breaks the modular pattern, makes them harder to reuse across environments, and concentrates a lot of boilerplate in `backend.tf`. They should be extracted into either a local module (`modules/security_groups/`) or replaced with the security group submodule pattern offered by the VPC module.

### RDS: Enable `deletion_protection` and disable `skip_final_snapshot`

Both flags are currently set in the permissive direction (`deletion_protection = false`, `skip_final_snapshot = true`). This means a `terraform destroy` or an accidental resource removal will immediately drop the database and leave no backup behind. In production, `deletion_protection = true` prevents accidental deletion, and `skip_final_snapshot = false` ensures a snapshot is taken before any destroy so data can be recovered.

### Add a resource tagging strategy

No AWS resource in the project has tags. Tags are required for cost allocation (which service/environment is spending what), lifecycle management (automated cleanup of stale resources), and compliance audits. A minimal tag set (`Project`, `Environment`, `ManagedBy = terraform`) should be defined in `locals.tf` and applied via `default_tags` in the provider block so every resource inherits them automatically.

### Decouple frontend S3 sync from Terraform

The frontend build is synced to S3 using a `terraform_data` resource with a `local-exec` provisioner. This mixes application deployment with infrastructure provisioning, which are separate concerns with different lifecycles. It also relies on the AWS CLI being installed on the machine running Terraform, which is not guaranteed in CI. The S3 sync should become an explicit step in the CI/CD deploy job (after `terraform apply`), making the deployment flow explicit and reproducible.

---

## CI/CD

### Use OIDC federation instead of static AWS credentials

The CI pipeline authenticates to AWS using long-lived access keys stored as GitHub Actions secrets. Static credentials are a security risk: they do not expire, can be leaked, and require manual rotation. AWS and GitHub both recommend OIDC (OpenID Connect) federation: the GitHub Actions runner receives a short-lived token scoped to the specific repository and workflow, with no long-lived secret to manage or rotate.

### Post `terraform plan` output as a PR comment

On feature branches, the CI runs `terraform plan` but the output is only visible inside the GitHub Actions log. Engineers reviewing a PR have no way to see what infra changes will be applied without opening the workflow run separately. The plan output (or a diff summary) should be posted as a comment on the pull request so infra reviewers can see it alongside the code changes.

### Trivy scanning for Docker images before ECR push

The backend Docker image is built and pushed to ECR without any vulnerability scan. A CVE in the base image (`python:3.12-slim`) or in a Python dependency would reach production undetected. Trivy should scan the built image before the push step; the job should fail if high or critical vulnerabilities are found, giving the team a chance to update the base image or dependency before it is deployed.

### Proper version tagging and tag-based deployments

Docker images are currently tagged with the commit SHA (e.g. `abc1234`). While unique, SHA tags are opaque: looking at ECR or an ECS task definition gives no indication of what version is running, whether it is a release or a development build, or how it relates to other images. A semantic versioning strategy (`v1.2.3`) should be adopted using Git tags. On push of a `v*` tag, the CI pipeline should build the Docker image, tag it with both the version (`v1.2.3`) and `latest`, push to ECR, and then trigger the ECS deployment using that version tag. This makes the running version visible at a glance in ECS, ECR, and deployment logs, and ensures rollbacks are a matter of redeploying a known, named image rather than hunting for a SHA.

---

## Backend

### Rate limiting

The `/links` endpoint has no rate limiting. Any client can call it indefinitely to fill the database with records, exhaust RDS storage, or cause a denial-of-service. A simple per-IP or global rate limit (e.g. via `slowapi` which integrates with FastAPI) would cap the blast radius of abusive clients.

### Structured logging

There is no logging anywhere in the application. When a production incident occurs (unexpected 500s, slow queries, repeated 404s), there is nothing to look at. The application should emit structured JSON logs (using Python's `logging` module or `structlog`) at appropriate levels, including at minimum: request method/path/status, error tracebacks, and link creation/resolution events.

### Health and readiness endpoints

The ALB health check currently targets `/docs` (the Swagger UI). This is not a meaningful health signal - the Swagger UI can respond 200 while the database is unreachable and every real request is failing. A dedicated `GET /health` endpoint (liveness: process is up) and `GET /ready` endpoint (readiness: DB connection works) would let the ALB and ECS accurately determine whether a task is serving traffic.

### Restrict CORS to the CloudFront domain

`allow_origins=["*"]` allows any origin to call the API directly, bypassing CloudFront entirely. This means unauthenticated cross-origin requests from arbitrary domains are accepted. CORS origins should be restricted to the CloudFront distribution URL, configurable via an environment variable so local development can still use `localhost`.

### URL input `max_length` validation

The `url` field in the request body is a plain `str` with no length constraint. A client could submit a multi-megabyte string that would be stored in the database and potentially cause memory issues during processing. Adding `max_length=2048` (the practical browser URL limit) to the Pydantic field prevents this.

### Database schema migrations with Alembic

The application calls `Base.metadata.create_all()` at startup. This works for the first deploy on an empty database, but it cannot apply schema changes to an existing database. Any future column addition, index change, or type modification would require manual SQL or a database recreation. Alembic provides versioned, reversible migrations that can be applied automatically at deploy time.

### Integration tests against a real database

All 15 existing tests mock the SQLAlchemy session. This means SQL constraint violations, connection pool behaviour, and transaction rollback are never tested. A separate integration test suite using a real PostgreSQL instance (e.g. via Docker Compose in CI or `pytest-postgresql`) would catch issues that only manifest against a real DB.

### Connection pool tuning

SQLAlchemy's default connection pool settings are used. As ECS autoscaling adds task instances, each one opens its own pool. RDS `db.t3.micro` has a `max_connections` of ~85. With 4 autoscaled tasks each holding the default pool, connections can be exhausted under load. `pool_size`, `max_overflow`, and `pool_recycle` should be set explicitly and matched to the RDS instance's limits.

### Observability and metrics

There is no instrumentation in the application. It is not possible to see request rates, error rates, or p99 latency without digging into ALB access logs. Adding OpenTelemetry (or even basic Prometheus metrics via `prometheus-fastapi-instrumentator`) would provide actionable signals for autoscaling decisions and incident response.

### Handle MD5 hash collision

If two different URLs hash to the same 8-character base62 ID, the `shorten` function silently returns the existing ID - which points to the first URL, not the one just submitted. The caller receives a shortened link that redirects to a different page. This edge case should be detected (compare the stored URL with the requested URL) and either surfaced as an error or handled with a fallback ID generation strategy.
