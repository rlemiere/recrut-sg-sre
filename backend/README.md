# URL Shortener — Backend

REST API that shortens URLs and redirects users to the original destination.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/links` | Accepts a URL in the request body, returns an 8-character short ID |
| `GET` | `/l/{id}` | Redirects (`302`) to the original URL, or returns `404` if the ID is unknown |

### POST /links

```json
// Request
{ "url": "https://example.com" }

// Response 201
{ "id": "aB3kR7mX" }
```

### GET /l/{id}

Returns `302 Moved` with a `Location` header pointing to the original URL.

## Link ID generation

1. The URL is hashed with MD5.
2. The 16 hash bytes are interpreted as a big-endian integer.
3. The integer is encoded in base62 (`0-9a-zA-Z`).
4. The result is truncated to **8 characters**.

Same URL always produces the same ID. Storing it twice is a no-op.

## Configuration

All variables can be set in a `.env` file at the root of the `backend/` folder or passed directly as environment variables.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DB_HOST` | string | `localhost` | PostgreSQL host |
| `DB_PORT` | integer | `5432` | PostgreSQL port (optional) |
| `DB_USERNAME` | string | `postgres` | Database user |
| `DB_PASSWORD` | string | `postgres` | Database password |
| `DB_NAME` | string | `urlshortener` | Database name |

The application assembles the connection URL from these values at startup — no `DATABASE_URL` variable is used.

## Running locally

```bash
# Start PostgreSQL (and pgAdmin at http://localhost:35432)
docker compose up -d

# Start the API server
uv run uvicorn app.main:app --reload
```

The API is available at `http://localhost:8000`.  
Swagger UI is available at `http://localhost:8000/docs`.

## Tests

```bash
uv run pytest -v
```

Tests use mocking and do not require a running database.
