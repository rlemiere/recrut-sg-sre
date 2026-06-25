# URL Shortener

A simple URL shortener with a React frontend and a FastAPI backend backed by PostgreSQL.

## How it works

Paste a URL into the input field and submit. The backend returns a shortened link. Visiting the short link redirects to the original URL.

## Stack

- **Frontend** — React (single page)
- **Backend** — Python / FastAPI / PostgreSQL

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
