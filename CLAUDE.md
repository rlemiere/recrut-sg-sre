# CLAUDE.md

## Global guidelines

Every time you make a change, update the CLAUDE.md to include a very small
text about what changed.

## Project layout

This project is a url shortener website. It is composed of the following
components :

- folder `frontend`: The frontend app in react

- folder `backend`: The backend app in python using fastapi

- folder `terraform`: The infrastructure to deploy the whole application.

This project will feature a postgresql database for the backend.

## Frontend

The frontend app is a react app composed of a single page. This page has a
single text field in which a user inputs an url with a button to send to the
backend. When sent to the backend, the backend will return the shortened link
to use.

## Backend

The backend app is a python uv-based project using fast api. It should serve
the following endpoints :

- `POST /links` : Receives a link from the user, shortens it, and stores it in
  the database.

- `GET /l/<link_id>` : Returns `302 Moved` to the proper link, or 404 page.

### Database structure

The database structure should be very simple :

A single table containing as primary key the id of the link, and a text field
containing the link to return to.

### Construction of the link id

The id of the link is created the following way :

1. The url is hashed using md5 algorithm

2. The **bytes** of the hash are encoded using base62

3. The base62 string is truncated to 8 chars.

## Infrastructure

### Terraform guidelines

You are a terraform expert using AWS. You must use provided aws modules from
the official provider. Only write resources if necessary. Always ask if there
is no existing aws module.

The database node must be not highly available, as the focus is on the pricing
for the RDS database.

Since it will be a small project, there is no need to refactor all the resources
in separate modules. Each kind of resource can be written in a dedicated
terraform file like :

- providers.tf for providers config

- variables.tf for variables

- backend.tf for backend resources.

The RDS database must be deployed in a private network.

The VPC and subnets must be setup by the project, follow the best security
practices.

### Resources to be deployed

The infrastructure will feature the following resources :

- An S3 bucket for the frontend page.

- A cloudfront gateway leading to the s3 bucket to serve the frontend.

- An ECS cluster to deploy the backend

- An RDS postgres database.

### The ECS Cluster for the backend

An ECS cluster must be deployed. It should support the following features :

- Container insights activated for the cluster.

- Healthcheck on /docs endpoint of the container

- Autoscaling based on memory and CPU.

---

## Recent changes

- Added `## Technical Choices` section to `README.md` documenting backend, frontend, and infrastructure decisions with pricing and vendor lock-in rationale.

## Backend — Current Status

The backend is **fully implemented**. Frontend and terraform are done.

The terraform infrastructure (`terraform/`) includes: VPC (public subnets + database subnets, no private subnets), ACM certificates (regional for ALB, us-east-1 for CloudFront), S3 + CloudFront distribution pointing to a public internet-facing ALB, ECS Fargate cluster + service (via `terraform-aws-modules/ecs/aws//modules/service`) with autoscaling, public ALB with HTTP→HTTPS redirect, RDS PostgreSQL 17 (db.t3.micro, single-AZ), Route53 records. DB password is auto-generated and stored in SSM Parameter Store.

ECS service was migrated from manual `aws_ecs_service` / `aws_ecs_task_definition` / IAM / autoscaling resources to the `terraform-aws-modules/ecs/aws//modules/service` submodule v7.5.0. Container-level healthcheck removed; ALB healthcheck with `health_check_grace_period_seconds = 120` is used instead.

### Stack

Python 3.12 · uv · FastAPI (sync) · SQLAlchemy 2.0 (sync) · psycopg3 (`psycopg[binary]`) · pydantic-settings

### Architecture

5-layer separation inside `backend/app/`:

| File            | Role                                                                               |
| --------------- | ---------------------------------------------------------------------------------- |
| `config.py`     | `Settings` via pydantic-settings; assembles the DB URL from individual env vars    |
| `database.py`   | Sync engine + `get_session()` FastAPI dependency                                   |
| `models.py`     | `Link` ORM model: `id` (PK, 8-char), `url`, `created_at` (indexed, server default) |
| `repository.py` | `get_link`, `create_link` — pure DB operations                                     |
| `service.py`    | `_make_link_id` (MD5 → base62 → 8 chars), `_validate_url`, `shorten`, `resolve`    |
| `router.py`     | `POST /links` (201/422), `GET /l/{link_id}` (302/404)                              |

### Configuration

Env vars (`.env` or environment): `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`

### Infrastructure files

- `docker-compose.yml` — postgres:17 + pgAdmin4 (host port 35432)
- `Dockerfile` — multi-stage build: uv builder → python:3.12-slim runtime, non-root user

### Other

- `openapi.yaml` — OpenAPI 3.0.3 spec
- `tests/` — 15 unit tests with mocking (pytest + pytest-asyncio), no real DB required
