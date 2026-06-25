from unittest.mock import patch

import pytest
from httpx import AsyncClient


async def test_post_links_returns_201_with_id(client: AsyncClient):
    with patch("app.service.shorten", return_value="abc12345"):
        response = await client.post("/links", json={"url": "https://example.com"})

    assert response.status_code == 201
    assert response.json() == {"id": "abc12345"}


async def test_post_links_returns_422_on_invalid_url(client: AsyncClient):
    with patch("app.service.shorten", side_effect=ValueError("Invalid URL")):
        response = await client.post("/links", json={"url": "bad-url"})

    assert response.status_code == 422
    assert "Invalid URL" in response.json()["detail"]


async def test_post_links_returns_422_on_missing_url_field(client: AsyncClient):
    response = await client.post("/links", json={})
    assert response.status_code == 422


async def test_get_redirect_returns_302_with_location(client: AsyncClient):
    with patch("app.service.resolve", return_value="https://example.com"):
        response = await client.get("/l/abc12345", follow_redirects=False)

    assert response.status_code == 302
    assert response.headers["location"] == "https://example.com"


async def test_get_redirect_returns_404_when_not_found(client: AsyncClient):
    with patch("app.service.resolve", return_value=None):
        response = await client.get("/l/notfound")

    assert response.status_code == 404
    assert response.json()["detail"] == "Link not found"
