from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import service
from app.database import get_session

router = APIRouter()

SessionDep = Annotated[Session, Depends(get_session)]


class ShortenRequest(BaseModel):
    url: str


class ShortenResponse(BaseModel):
    id: str


@router.post("/links", response_model=ShortenResponse, status_code=201)
async def shorten_link(body: ShortenRequest, session: SessionDep) -> ShortenResponse:
    try:
        link_id = service.shorten(session, body.url)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return ShortenResponse(id=link_id)


@router.get("/l/{link_id}")
async def redirect_link(link_id: str, session: SessionDep) -> RedirectResponse:
    url = service.resolve(session, link_id)
    if url is None:
        raise HTTPException(status_code=404, detail="Link not found")
    return RedirectResponse(url=url, status_code=302)
