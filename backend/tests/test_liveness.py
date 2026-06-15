import os
import pytest
from fastapi.testclient import TestClient

# Set environment variables for testing before importing the app
os.environ["MOCK_AWS"] = "True"
os.environ["AWS_REGION"] = "us-east-1"
os.environ["COGNITO_POOL_ID"] = "us-east-1:mock-pool-id"
os.environ["DATABASE_URL"] = "sqlite:///./test_liveness.db"
os.environ["LIVENESS_PROVIDER"] = "mock_provider"

from app.main import app
from app.config import settings
from app.services.liveness_service import get_liveness_service
from app.database import Base, engine
from app.models import LivenessSession, Customer


# Create schemas in the local SQLite database for testing
Base.metadata.drop_all(bind=engine) # clean start
Base.metadata.create_all(bind=engine)

from sqlalchemy.orm import sessionmaker
from app.models import ApiKey
from app.auth_utils import hash_api_key
import time

SessionLocal = sessionmaker(bind=engine)
db = SessionLocal()
try:
    hashed_key = hash_api_key("test_api_key_123")
    api_key_record = ApiKey(
        key_hash=hashed_key,
        name="default",
        is_active=True,
        created_at=time.time()
    )
    db.add(api_key_record)
    db.commit()
finally:
    db.close()

client = TestClient(app)

@pytest.fixture(scope="session", autouse=True)
def cleanup_test_db():
    yield
    try:
        # Close all connections first
        engine.dispose()
        if os.path.exists("./test_liveness.db"):
            os.remove("./test_liveness.db")
    except Exception as e:
        print(f"Failed to remove test database: {e}")

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["mock_mode"] is True
    assert data["environment"] == "development"

def test_create_session_unauthorized():
    # 1. Missing API Key
    response = client.post("/api/v1/liveness/session?preferred_mode=ACTIVE")
    assert response.status_code == 401
    assert "required" in response.json()["detail"]

    # 2. Invalid API Key
    response2 = client.post("/api/v1/liveness/session?preferred_mode=ACTIVE", headers={"X-API-Key": "wrong_key"})
    assert response2.status_code == 401
    assert "Invalid" in response2.json()["detail"]

def test_create_session():
    response = client.post(
        "/api/v1/liveness/session?preferred_mode=ACTIVE",
        headers={"X-API-Key": "test_api_key_123"}
    )
    assert response.status_code == 201
    data = response.json()
    assert "session_id" in data
    assert data["provider"] == "mock_provider"
    assert data["status"] == "CREATED"
    assert data["liveness_mode"] == "ACTIVE"
    assert data["cognito_pool_id"] is None
    assert data["cognito_region"] is None

def test_verify_session_pass():
    # Create session first
    create_response = client.post(
        "/api/v1/liveness/session",
        headers={"X-API-Key": "test_api_key_123"}
    )
    assert create_response.status_code == 201
    session_id = create_response.json()["session_id"]

    # Verify session
    payload = {
        "session_id": session_id,
        "device_intelligence": {
            "device_id": "test_device_id",
            "device_model": "iPhone Test",
            "device_os": "iOS 17",
            "ip_address": "127.0.0.1",
            "latitude": "6.5244",
            "longitude": "3.3792"
        }
    }
    verify_response = client.post("/api/v1/liveness/verify", json=payload)
    assert verify_response.status_code == 200
    verify_data = verify_response.json()
    assert verify_data["status"] == "PASS"
    assert verify_data["confidence"] == 98.7
    assert verify_data["provider_session_id"] == session_id
    assert "image_reference" in verify_data

def test_verify_session_fail():
    # Insert a custom mock session ending in "fail" into the service's store
    session_id = "mock_session_test_fail"
    service = get_liveness_service()
    service._sessions[session_id] = {
        "session_id": session_id,
        "provider": "mock_provider",
        "status": "CREATED",
        "liveness_mode": "PASSIVE",
        "created_at": 0.0
    }

    payload = {
        "session_id": session_id,
        "device_intelligence": {
            "device_id": "test_device_id",
            "device_model": "iPhone Test",
            "device_os": "iOS 17",
            "ip_address": "127.0.0.1"
        }
    }
    verify_response = client.post("/api/v1/liveness/verify", json=payload)
    assert verify_response.status_code == 200
    verify_data = verify_response.json()
    assert verify_data["status"] == "FAIL"
    assert verify_data["confidence"] == 45.2

def test_verify_session_low_confidence():
    # Insert a custom mock session ending in "low" into the service's store
    session_id = "mock_session_test_low"
    service = get_liveness_service()
    service._sessions[session_id] = {
        "session_id": session_id,
        "provider": "mock_provider",
        "status": "CREATED",
        "liveness_mode": "PASSIVE",
        "created_at": 0.0
    }

    payload = {
        "session_id": session_id,
    }
    verify_response = client.post("/api/v1/liveness/verify", json=payload)
    assert verify_response.status_code == 200
    verify_data = verify_response.json()
    assert verify_data["status"] == "LOW_CONFIDENCE"
    assert verify_data["confidence"] == 88.5

def test_create_customer():
    # 1. Register customer
    payload = {
        "bvn": "11122233344",
        "email": "cust@bvn.com",
        "phone": "+2348000000000",
        "channel": "personal"
    }
    response = client.post("/api/v1/liveness/customer", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert "customer_id" in data
    assert "-" in data["customer_id"] # check it is a valid UUID
    assert data["bvn"] == "11122233344"
    assert data["email"] == "cust@bvn.com"
    assert data["phone"] == "+2348000000000"
    assert data["channel"] == "personal"
    customer_id = data["customer_id"]

    # 2. Create session with this customer_id and bvn
    session_response = client.post(
        f"/api/v1/liveness/session?user_id={customer_id}&bvn=11122233344&channel=personal&verification_type=ONBOARDING",
        headers={"X-API-Key": "test_api_key_123"}
    )
    assert session_response.status_code == 201
    session_data = session_response.json()
    assert session_data["user_id"] == customer_id
    assert session_data["bvn"] == "11122233344"
    assert session_data["channel"] == "personal"
    assert session_data["verification_type"] == "ONBOARDING"
    assert "-" in session_data["session_id"] # check it is a valid UUID without custom prefix

def test_customer_uniqueness_and_retry():
    bvn = "22255566677"
    # Onboard on personal channel
    payload1 = {
        "bvn": bvn,
        "email": "p@test.com",
        "phone": "+2341",
        "channel": "personal"
    }
    resp1 = client.post("/api/v1/liveness/customer", json=payload1)
    assert resp1.status_code == 201
    customer_id = resp1.json()["customer_id"]

    # Trying to onboard on personal channel again before any session PASSes should be allowed (retry)
    resp2 = client.post("/api/v1/liveness/customer", json=payload1)
    assert resp2.status_code == 201
    assert resp2.json()["customer_id"] == customer_id # same ID returned

    # Create a PASS session for this customer
    sess_resp = client.post(
        f"/api/v1/liveness/session?user_id={customer_id}&bvn={bvn}&channel=personal",
        headers={"X-API-Key": "test_api_key_123"}
    )
    sess_id = sess_resp.json()["session_id"]
    verify_resp = client.post("/api/v1/liveness/verify", json={"session_id": sess_id})
    assert verify_resp.status_code == 200
    assert verify_resp.json()["status"] == "PASS"

    # Now onboarding on personal channel again should be BLOCKED because there is a PASS session
    resp3 = client.post("/api/v1/liveness/customer", json=payload1)
    assert resp3.status_code == 400
    assert "already onboarded" in resp3.json()["detail"]

    # However, onboarding on business channel should still be ALLOWED (channel isolation)
    payload2 = {
        "bvn": bvn,
        "email": "p@test.com",
        "phone": "+2341",
        "channel": "business"
    }
    resp4 = client.post("/api/v1/liveness/customer", json=payload2)
    assert resp4.status_code == 201
    assert resp4.json()["customer_id"] != customer_id # new customer ID for business channel

def test_face_verification_flow():
    # 1. Onboard a customer
    bvn = "33377788899"
    payload = {
        "bvn": bvn,
        "email": "f@test.com",
        "phone": "+2342",
        "channel": "personal"
    }
    cust_resp = client.post("/api/v1/liveness/customer", json=payload)
    cust_id = cust_resp.json()["customer_id"]

    # Create onboarding session and verify (simulates registering reference face)
    onb_sess = client.post(
        f"/api/v1/liveness/session?user_id={cust_id}&bvn={bvn}&verification_type=ONBOARDING",
        headers={"X-API-Key": "test_api_key_123"}
    )
    onb_sess_id = onb_sess.json()["session_id"]
    verify_onb = client.post("/api/v1/liveness/verify", json={"session_id": onb_sess_id})
    assert verify_onb.status_code == 200

    # 2. Trigger face verification session for this user (should MATCH successfully)
    ver_sess = client.post(
        f"/api/v1/liveness/session?user_id={cust_id}&bvn={bvn}&verification_type=VERIFICATION",
        headers={"X-API-Key": "test_api_key_123"}
    )
    ver_sess_id = ver_sess.json()["session_id"]
    verify_ver = client.post("/api/v1/liveness/verify", json={"session_id": ver_sess_id})
    assert verify_ver.status_code == 200
    
    # Check session details to ensure face_match columns are populated
    from sqlalchemy.orm import sessionmaker
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()
    try:
        db_sess = db.query(LivenessSession).filter(LivenessSession.session_id == ver_sess_id).first()
        assert db_sess is not None
        assert db_sess.verification_type == "VERIFICATION"
        assert db_sess.face_match_status == "MATCH"
        assert db_sess.face_match_confidence == 98.2

        # Create the mismatch customer record in the DB
        mism_cust_id = cust_id + "_mismatch"
        mism_bvn = "44488899900"
        db_cust_mism = Customer(
            customer_id=mism_cust_id,
            bvn=mism_bvn,
            email="mism@test.com",
            phone="+2343",
            channel="personal",
            reference_image_path="s3://bucket/dummy.jpg"
        )
        db.add(db_cust_mism)
        db.commit()

        # 3. Trigger face verification session ending in 'mismatch' (should MISMATCH and FAIL)
        ver_sess2 = client.post(
            f"/api/v1/liveness/session?user_id={mism_cust_id}&bvn={mism_bvn}&verification_type=VERIFICATION",
            headers={"X-API-Key": "test_api_key_123"}
        )
        ver_sess_id2 = ver_sess2.json()["session_id"]
        verify_ver2 = client.post("/api/v1/liveness/verify", json={"session_id": ver_sess_id2})
        assert verify_ver2.json()["status"] == "FAIL"

        db_sess2 = db.query(LivenessSession).filter(LivenessSession.session_id == ver_sess_id2).first()
        assert db_sess2 is not None
        assert db_sess2.face_match_status == "MISMATCH"
        assert db_sess2.face_match_confidence == 42.1
    finally:
        db.close()


