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
