# URL Shortener

A simple URL shortener with a React frontend and a FastAPI backend backed by PostgreSQL.

## How it works

Paste a URL into the input field and submit. The backend returns a shortened link. Visiting the short link redirects to the original URL.

## Stack

- **Frontend** - React (single page)
- **Backend** - Python / FastAPI / PostgreSQL

## Technical Choices

All technology choices below are sized to the current scale of the product. Pricing trade-offs reflect a small deployment, not a hypothetical future load. Most technologies were also selected to stay as close as possible to open standards and avoid vendor lock-in.

### Backend

**Python / FastAPI + uv** - a standard, production-ready stack with minimal setup overhead. FastAPI is widely adopted, well-documented, and straightforward to deploy anywhere.

### Frontend

**React + TypeScript** - a standard, production-ready stack. React has broad ecosystem support; TypeScript catches errors early without adding runtime overhead.

### Infrastructure

**S3 + CloudFront** for the frontend - simple to set up and aggressively priced at small scale. Static assets served from the edge with no servers to manage.

**ECS Fargate** for the backend - chosen over EKS on cost (no control-plane fee) and over Lambda to avoid vendor lock-in. ECS handles autoscaling for traffic bursts and can be replaced by a Kubernetes cluster with minimal migration effort.

**RDS PostgreSQL** for storage - DynamoDB could lower the bill slightly, but PostgreSQL is an open standard: no proprietary query language or API to migrate away from. The instance is a single-AZ `db.t3.micro`, appropriate for the current product size.

## API

| Method | Path      | Description                                |
| ------ | --------- | ------------------------------------------ |
| `POST` | `/links`  | Submit a URL, get back a short link        |
| `GET`  | `/l/<id>` | Redirect to the original URL (302), or 404 |

## CI

The GitHub Actions workflow lints, builds, publishes, and deploys on every push.

Configure the following in **Settings → Secrets and Variables → Actions**.

### Secrets

| Secret                  | Description                                                                |
| ----------------------- | -------------------------------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | IAM access key                                                             |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key                                                             |
| `ECR_REPOSITORY`        | Public ECR repo path: `<alias>/<name>`, e.g. `myalias/rlemiere-sg-backend` |
| `TF_BACKEND_BUCKET`     | S3 bucket holding the Terraform state                                      |
| `TF_BACKEND_KEY`        | State file path, e.g. `rlemiere-sg/terraform.tfstate`                      |
| `TF_BACKEND_REGION`     | Region of the state bucket, e.g. `eu-west-2`                               |

### Variables

| Variable     | Value                                   |
| ------------ | --------------------------------------- |
| `AWS_REGION` | AWS deployment region, e.g. `eu-west-2` |
