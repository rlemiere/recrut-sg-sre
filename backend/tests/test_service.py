from unittest.mock import MagicMock, patch

import pytest

from app import service
from app.models import Link


def test_shorten_creates_link_when_not_found():
    session = MagicMock()
    with (
        patch("app.service.repository.get_link", return_value=None) as mock_get,
        patch("app.service.repository.create_link") as mock_create,
    ):
        link_id = service.shorten(session, "https://example.com")

    assert len(link_id) == 8
    mock_get.assert_called_once_with(session, link_id)
    mock_create.assert_called_once_with(session, link_id, "https://example.com")


def test_shorten_skips_create_when_link_already_exists():
    session = MagicMock()
    with (
        patch(
            "app.service.repository.get_link",
            return_value=Link(id="abc12345", url="https://example.com"),
        ),
        patch("app.service.repository.create_link") as mock_create,
    ):
        service.shorten(session, "https://example.com")

    mock_create.assert_not_called()


def test_shorten_raises_on_missing_scheme():
    with pytest.raises(ValueError, match="Invalid URL"):
        service.shorten(MagicMock(), "example.com")


def test_shorten_raises_on_non_http_scheme():
    with pytest.raises(ValueError, match="Invalid URL"):
        service.shorten(MagicMock(), "ftp://example.com")


def test_shorten_raises_on_empty_string():
    with pytest.raises(ValueError, match="Invalid URL"):
        service.shorten(MagicMock(), "")


def test_make_link_id_is_deterministic():
    assert service._make_link_id("https://example.com") == service._make_link_id(
        "https://example.com"
    )


def test_make_link_id_returns_eight_chars():
    assert len(service._make_link_id("https://example.com")) == 8


def test_make_link_id_differs_for_different_urls():
    assert service._make_link_id("https://a.com") != service._make_link_id(
        "https://b.com"
    )


def test_resolve_returns_url_when_link_exists():
    session = MagicMock()
    link = Link(id="abc12345", url="https://example.com")
    with patch("app.service.repository.get_link", return_value=link):
        result = service.resolve(session, "abc12345")
    assert result == "https://example.com"


def test_resolve_returns_none_when_not_found():
    session = MagicMock()
    with patch("app.service.repository.get_link", return_value=None):
        result = service.resolve(session, "notfound")
    assert result is None
