import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.db.session import Base, get_db

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
async def test_full_slice1_ai_and_medication_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Health check
        res = await client.get("/health")
        assert res.status_code == 200
        assert res.json()["status"] == "healthy"

        # 2. Register user
        res = await client.post("/api/v1/auth/register", json={
            "email": "alex@example.com",
            "password": "Password123!",
            "name": "Alex Caregiver",
            "phone": "+1234567890"
        })
        assert res.status_code == 201
        data = res.json()
        token = data["token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 3. AI Voice Intent Parsing - SET SCHEDULE
        # Query: "Hey, I need to take vitamin d, once every week for next 6 weeks"
        res = await client.post(
            "/api/v1/ai/parse-intent",
            headers=headers,
            json={"text": "I need to take vitamin d, once every week for next 6 weeks"}
        )
        assert res.status_code == 200
        intent = res.json()
        assert intent["action"] == "SET_SCHEDULE"
        assert intent["set_schedule_data"]["name"] == "Vitamin D"
        assert intent["set_schedule_data"]["frequency"] == "weekly"
        assert intent["set_schedule_data"]["duration_weeks"] == 6

        # 4. Save Medication based on confirmed schedule
        sched = intent["set_schedule_data"]
        res = await client.post(
            "/api/v1/medications",
            headers=headers,
            json={
                "name": sched["name"],
                "dosage": sched["dosage"],
                "frequency": sched["frequency"],
                "duration_weeks": sched["duration_weeks"],
                "instructions": sched["instructions"]
            }
        )
        assert res.status_code == 201
        med_data = res.json()
        med_id = med_data["id"]
        assert med_data["inventory_count"] == 6

        # 5. Check Today's Doses
        res = await client.get("/api/v1/medications/doses/today", headers=headers)
        assert res.status_code == 200
        doses = res.json()
        assert len(doses) >= 1
        dose_id = doses[0]["id"]
        assert doses[0]["status"] == "pending"
        assert doses[0]["medication_name"] == "Vitamin D"

        # 6. AI Voice Intent Parsing - RECORD DOSE
        res = await client.post(
            "/api/v1/ai/parse-intent",
            headers=headers,
            json={"text": "I just took vit d in the morning"}
        )
        assert res.status_code == 200
        record_intent = res.json()
        assert record_intent["action"] == "RECORD_DOSE"
        assert record_intent["record_dose_data"]["name"] == "Vitamin D"

        # 7. Take Dose & Verify Inventory Decrement
        res = await client.post(f"/api/v1/medications/doses/{dose_id}/take", headers=headers)
        assert res.status_code == 200
        taken_dose = res.json()
        assert taken_dose["status"] == "taken"
        assert taken_dose["actual_time"] is not None

        # Verify medication inventory decremented from 6 to 5
        res = await client.get("/api/v1/medications", headers=headers)
        med_list = res.json()
        assert med_list[0]["inventory_count"] == 5

        # 8. Test Instant Undo
        res = await client.post(f"/api/v1/medications/doses/{dose_id}/undo", headers=headers)
        assert res.status_code == 200
        undone_dose = res.json()
        assert undone_dose["status"] == "pending"
        assert undone_dose["actual_time"] is None

        # 9. Test Prescription OCR Scan
        res = await client.post(
            "/api/v1/ai/scan-prescription",
            headers=headers,
            files={"file": ("rx_test.jpg", b"fake_image_bytes", "image/jpeg")}
        )
        assert res.status_code == 200
        ocr = res.json()
        assert len(ocr["medications"]) >= 1

        # 10. Test RAG Health Chat
        res = await client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={
                "query": "What medications am I taking and when was my last dose?",
                "conversation_history": []
            }
        )
        assert res.status_code == 200
        chat = res.json()
        assert "response" in chat
        assert len(chat["response"]) > 0

@pytest.mark.asyncio
async def test_anonymous_login_and_persistence():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # First anonymous login with device id
        res = await client.post("/api/v1/auth/anonymous", json={
            "device_id": "test-device-uuid-123",
            "name": "Guest Patient"
        })
        assert res.status_code == 200
        data = res.json()
        assert "token" in data
        assert data["user"]["name"] == "Guest Patient"
        assert data["user"]["email"] == "guest_test-device-uuid-123@gobi.local"

        # Re-login with same device id returns same user
        res2 = await client.post("/api/v1/auth/anonymous", json={
            "device_id": "test-device-uuid-123"
        })
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["user"]["id"] == data["user"]["id"]

@pytest.mark.asyncio
async def test_dependent_idor_and_scheduling_edge_cases():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Register user A
        res_a = await client.post("/api/v1/auth/register", json={
            "email": "user_a@example.com",
            "password": "Password123!",
            "name": "User A"
        })
        token_a = res_a.json()["token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        # User A creates dependent
        dep_res = await client.post("/api/v1/dependents", headers=headers_a, json={
            "name": "User A Dependent",
            "relationship_type": "child"
        })
        dep_id_a = dep_res.json()["id"]

        # Register user B
        res_b = await client.post("/api/v1/auth/register", json={
            "email": "user_b@example.com",
            "password": "Password123!",
            "name": "User B"
        })
        token_b = res_b.json()["token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}

        # User B attempts to attach medication to User A's dependent (IDOR attempt)
        res_attack = await client.post("/api/v1/medications", headers=headers_b, json={
            "name": "Malicious Med",
            "dependent_id": dep_id_a,
            "frequency": "daily"
        })
        assert res_attack.status_code == 404

        # User B creates valid twice_daily medication with custom times
        res_med = await client.post("/api/v1/medications", headers=headers_b, json={
            "name": "Metformin",
            "dosage": "500mg",
            "frequency": "twice_daily",
            "times": "08:00, 20:00",
            "duration_weeks": 2
        })
        assert res_med.status_code == 201
        med_b = res_med.json()
        # 2 weeks * 7 days * 2 times = 28 doses
        assert med_b["inventory_count"] == 28
