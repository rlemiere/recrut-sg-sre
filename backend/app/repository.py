from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Link


def get_link(session: Session, link_id: str) -> Link | None:
    return session.execute(select(Link).where(Link.id == link_id)).scalar_one_or_none()


def create_link(session: Session, link_id: str, url: str) -> None:
    session.add(Link(id=link_id, url=url))
    session.commit()
