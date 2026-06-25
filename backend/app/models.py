from sqlalchemy import String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Link(Base):
    __tablename__ = "links"

    id: Mapped[str] = mapped_column(String(8), primary_key=True)
    url: Mapped[str] = mapped_column(String, nullable=False)
