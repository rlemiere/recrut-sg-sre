from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import engine
from app.models import Base
from app.router import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    yield


app = FastAPI(title="URL Shortener", lifespan=lifespan)
app.include_router(router)
