import hashlib
import string
from urllib.parse import urlparse

from sqlalchemy.orm import Session

from app import repository

_BASE62 = string.digits + string.ascii_lowercase + string.ascii_uppercase


def _make_link_id(url: str) -> str:
    digest = hashlib.md5(url.encode()).digest()
    n = int.from_bytes(digest, "big")
    chars: list[str] = []
    while n:
        n, rem = divmod(n, 62)
        chars.append(_BASE62[rem])
    return "".join(reversed(chars))[:8]


def _validate_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ValueError(f"Invalid URL '{url}': must use http or https scheme with a valid host")


def shorten(session: Session, url: str) -> str:
    _validate_url(url)
    link_id = _make_link_id(url)
    if not repository.get_link(session, link_id):
        repository.create_link(session, link_id, url)
    return link_id


def resolve(session: Session, link_id: str) -> str | None:
    link = repository.get_link(session, link_id)
    return link.url if link else None
