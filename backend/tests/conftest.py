from contextlib import asynccontextmanager
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.database import get_session
from app.router import router


@asynccontextmanager
async def _noop_lifespan(app: FastAPI):
    yield


@pytest.fixture
def mock_session() -> MagicMock:
    return MagicMock()


@pytest.fixture
async def client(mock_session: MagicMock) -> AsyncClient:
    test_app = FastAPI(lifespan=_noop_lifespan)
    test_app.include_router(router)
    test_app.dependency_overrides[get_session] = lambda: mock_session

    async with AsyncClient(transport=ASGITransport(app=test_app), base_url="http://test") as c:
        yield c
