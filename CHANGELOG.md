# Changelog

All notable changes to this project are documented here.

## [Unreleased]

---

## [2026-06-24] — CI/CD pipeline

### Added

- GitHub Actions workflow (`.github/workflows/ci.yml`) with four stages on `main`:
  lint → build → publish → deploy; feature branches get lint + `terraform plan`
- `ruff` added to backend dev dependencies so CI linting works outside Nix
- Frontend S3 sync managed by Terraform via `terraform_data` with `local-exec` provisioner,
  triggered by `frontend_version` (git SHA injected from CI)
- CloudFront cache invalidation after S3 sync using the `aws_cloudfront_create_invalidation`
  Terraform action, fired via `action_trigger` on `after_create`
- Backend image split into `backend_repository` (stable repo URL, stored in `terraform.tfvars`)
  and `backend_version` (git SHA, injected at apply time from CI); image URI constructed as
  `"${var.backend_repository}:${var.backend_version}"` in the ECS task definition
- CI documentation in `README.md` listing required secrets and variables

### Changed

- Backend Docker image pushed to **public ECR** (`public.ecr.aws`) instead of private ECR;
  `amazon-ecr-login@v2` now uses `registry-type: public`
- `ECR_REGISTRY` secret removed — registry host is always `public.ecr.aws`
- `backend_image_uri` terraform variable replaced by `backend_repository` + `backend_version`
- Node upgraded from 22 to 24 in CI
- `concurrency` group on workflow prevents concurrent `terraform apply` runs on `main`

### Fixed

- Frontend URL fallback added to avoid broken API calls when `VITE_API_URL` is not set

---

## [2026-06-24] — Infrastructure

### Added

- Terraform infrastructure: VPC with public and database subnets across two AZs
- S3 bucket + CloudFront distribution for the frontend (OAC, SPA error routing)
- ECS Fargate cluster with autoscaling (CPU + memory), ALB, container insights enabled
- RDS PostgreSQL 17 (`db.t3.micro`, single-AZ, private subnet)
- ACM certificates: regional for ALB, `us-east-1` for CloudFront
- Route53 alias records for frontend (→ CloudFront) and API (→ ALB)
- S3 backend for Terraform state with native lockfile (`use_lockfile = true`)
- DB password auto-generated and stored in SSM Parameter Store

### Fixed

- ECS moved to public subnets to avoid needing a NAT gateway
- HTTPS redirect added on ALB and CloudFront
- Missing ECS service resource added

---

## [2026-06-24] — Frontend

### Added

- React 19 + TypeScript 5 + Vite 6 single-page app
- URL input form: submits to `POST /links`, displays the returned short link
- CORS support on the backend for the frontend origin

---

## [2026-06-24] — Backend

### Added

- FastAPI URL shortener with two endpoints: `POST /links` and `GET /l/{id}`
- Link ID algorithm: MD5 hash of URL → base62-encode bytes → truncate to 8 chars
- SQLAlchemy 2.0 (sync) + psycopg3 ORM with `Link` model (`id`, `url`, `created_at`)
- `created_at` column with server-side default and index
- pydantic-settings for configuration via environment variables
- Multi-stage Dockerfile (uv builder → `python:3.12-slim`, non-root user)
- OpenAPI spec (`openapi.yaml`)
- Unit test suite (15 tests, fully mocked, no database required)
