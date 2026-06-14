import time
from sqlalchemy import Column, Integer, String, Boolean, Float, Text, UniqueConstraint
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default="admin", nullable=False)
    created_at = Column(Float, default=time.time, nullable=False)

class Invite(Base):
    __tablename__ = "invites"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    created_by = Column(String, nullable=False)  # Admin who generated it
    is_used = Column(Boolean, default=False, nullable=False)
    used_by = Column(String, nullable=True)      # Email of registered user
    created_at = Column(Float, default=time.time, nullable=False)

class Customer(Base):
    __tablename__ = "customers"
    __table_args__ = (UniqueConstraint('bvn', 'channel', name='_bvn_channel_uc'),)

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(String, unique=True, index=True, nullable=False)
    bvn = Column(String, index=True, nullable=False)
    channel = Column(String, default="personal", nullable=False)  # personal or business
    email = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    reference_image_path = Column(String, nullable=True)  # Path to saved reference face
    created_at = Column(Float, default=time.time, nullable=False)

class LivenessSession(Base):
    __tablename__ = "liveness_sessions"

    session_id = Column(String, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=True)  # CST/banking user ID
    bvn = Column(String, index=True, nullable=True)       # Link to customer's BVN
    channel = Column(String, default="personal", nullable=True)  # personal or business
    verification_type = Column(String, default="ONBOARDING", nullable=False) # ONBOARDING or VERIFICATION
    face_match_status = Column(String, nullable=True)     # MATCH or MISMATCH
    face_match_confidence = Column(Float, nullable=True)  # Face comparison confidence
    provider = Column(String, nullable=False)            # aws_rekognition, google_ml_kit, etc.
    liveness_mode = Column(String, nullable=False)       # PASSIVE, ACTIVE, etc.
    status = Column(String, default="CREATED", nullable=False)
    confidence = Column(Float, default=0.0, nullable=False)
    image_reference = Column(String, default="", nullable=True)
    video_reference = Column(String, default="", nullable=True)
    device_intelligence = Column(Text, default="", nullable=True)  # JSON-encoded telemetry string
    created_at = Column(Float, default=time.time, nullable=False)
    updated_at = Column(Float, default=time.time, onupdate=time.time, nullable=False)

