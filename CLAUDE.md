# CLAUDE.md

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

---

## Backend — Current Status

The backend is **fully implemented**. Frontend and terraform are not yet started.

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
