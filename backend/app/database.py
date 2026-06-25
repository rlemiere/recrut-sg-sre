from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings

engine = create_engine(settings.database_url)
_session_factory = sessionmaker(engine)


def get_session() -> Generator[Session, None, None]:
    with _session_factory() as session:
        yield session
