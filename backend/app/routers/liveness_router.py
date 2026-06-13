import logging
import time
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.services.liveness_service import LivenessService, get_liveness_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/liveness", tags=["liveness"])

# --- Request / Response Models ---

class SessionCreateResponse(BaseModel):
    session_id: str
    provider: str
    status: str
    liveness_mode: str

class DeviceTelemetry(BaseModel):
    device_id: Optional[str] = Field(None, description="Unique identifier of the device")
    device_model: Optional[str] = Field(None, description="Model of the device, e.g. iPhone 15 Pro")
    device_os: Optional[str] = Field(None, description="OS of the device, e.g. iOS 17.2")
    ip_address: Optional[str] = Field(None, description="Client IP address")
    latitude: Optional[str] = Field(None, description="Client coordinates latitude")
    longitude: Optional[str] = Field(None, description="Client coordinates longitude")

class VerifySessionRequest(BaseModel):
    session_id: str = Field(..., description="The AWS Rekognition/Mock Session ID")
    device_intelligence: Optional[DeviceTelemetry] = Field(None, description="Telemetry details for fraud analytics")

class VerifySessionResponse(BaseModel):
    status: str = Field(..., description="Outcome of the verification: PASS, FAIL, TIMEOUT, CAMERA_DENIED, NETWORK_ERROR, LOW_CONFIDENCE, MEDIUM_RISK")
    confidence: float = Field(..., description="Liveness confidence percentage score (0.0 to 100.0)")
    provider_session_id: str
    timestamp: float
    image_reference: Optional[str] = None


# --- Endpoints ---

@router.post(
    "/session",
    response_model=SessionCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Liveness Session",
    description="Initiates a new face liveness verification session with AWS Rekognition or the mock provider."
)
async def create_session(
    preferred_mode: Optional[str] = None,
    service: LivenessService = Depends(get_liveness_service)
):
    try:
        session_info = service.create_session(preferred_mode=preferred_mode)
        return SessionCreateResponse(
            session_id=session_info["session_id"],
            provider=session_info["provider"],
            status=session_info["status"],
            liveness_mode=session_info["liveness_mode"]
        )
    except Exception as e:
        logger.error(f"Failed to create liveness session: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create session: {str(e)}"
        )


@router.post(
    "/verify",
    response_model=VerifySessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify Liveness Session",
    description="Retrieves the verification results, evaluates fraud rules, and logs device intelligence metadata."
)
async def verify_session(
    payload: VerifySessionRequest,
    service: LivenessService = Depends(get_liveness_service)
):
    try:
        # Log Device Intelligence details for auditability (FR-010 / Section 11)
        if payload.device_intelligence:
            telemetry = payload.device_intelligence
            logger.info(
                f"[Audit Log] Verification Session: {payload.session_id} | "
                f"DeviceID: {telemetry.device_id} | Model: {telemetry.device_model} | "
                f"OS: {telemetry.device_os} | IP: {telemetry.ip_address} | "
                f"Coords: ({telemetry.latitude}, {telemetry.longitude})"
            )
        else:
            logger.warning(f"[Audit Log] Verification Session: {payload.session_id} - No Device Intelligence data provided")

        result = service.verify_session(payload.session_id)
        
        return VerifySessionResponse(
            status=result["status"],
            confidence=result["confidence"],
            provider_session_id=result["session_id"],
            timestamp=result["timestamp"],
            image_reference=result.get("image_reference")
        )
    except Exception as e:
        logger.error(f"Failed to verify liveness session {payload.session_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify session: {str(e)}"
        )
