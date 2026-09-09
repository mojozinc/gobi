import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.db.session import Base, get_db
from app.db.models import User, Medication, DoseLog
from datetime import datetime, timezone, timedelta

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
TestSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

async def override_get_db():
    async with TestSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

app.dependency_overrides[get_db] = override_get_db

@pytest_asyncio.fixture(autouse=True)
async def init_test_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest.mark.asyncio
async def test_ai_chat_smoke_empty_history():
    """Smoke test /api/v1/ai/chat with empty history."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Anonymous Login
        auth_res = await client.post("/api/v1/auth/anonymous", json={
            "device_id": "smoke_chat_device",
            "name": "Smoke Patient"
        })
        assert auth_res.status_code == 200
        token = auth_res.json()["token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Call /api/v1/ai/chat
        chat_res = await client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={
                "query": "Hello, how can I track my medications?",
                "conversation_history": []
            }
        )
        assert chat_res.status_code == 200
        data = chat_res.json()
        assert "response" in data
        assert len(data["response"]) > 0
        assert isinstance(data["referenced_medications"], list)
        assert isinstance(data["referenced_documents"], list)

@pytest.mark.asyncio
async def test_ai_chat_smoke_with_medications_and_history():
    """Smoke test /api/v1/ai/chat with seeded active medications and conversation history."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Login
        auth_res = await client.post("/api/v1/auth/anonymous", json={
            "device_id": "smoke_chat_device_2",
            "name": "Amoxicillin Patient"
        })
        token = auth_res.json()["token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Add Medication
        med_res = await client.post(
            "/api/v1/medications",
            headers=headers,
            json={
                "name": "Amoxicillin",
                "dosage": "500mg",
                "frequency": "daily",
                "duration_weeks": 1,
                "instructions": "Take with water after breakfast"
            }
        )
        assert med_res.status_code == 201

        # 3. Call Chat with History
        history = [
            {"role": "user", "content": "What pills do I have?"},
            {"role": "assistant", "content": "You have Amoxicillin 500mg scheduled daily."}
        ]
        chat_res = await client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={
                "query": "Should I take it with food?",
                "conversation_history": history
            }
        )
        assert chat_res.status_code == 200
        data = chat_res.json()
        assert "response" in data
        assert len(data["response"]) > 0
