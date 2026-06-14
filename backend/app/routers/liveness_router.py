import logging
import time
import json
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from pydantic import BaseModel, Field
import boto3
from sqlalchemy.orm import Session

from app.config import settings
from app.services.liveness_service import LivenessService, get_liveness_service
from app.database import get_db
from app.models import LivenessSession, User, Customer
from app.routers.auth_router import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/liveness", tags=["liveness"])

# --- Request / Response Models ---

class SessionCreateResponse(BaseModel):
    session_id: str
    provider: str
    status: str
    liveness_mode: str
    cognito_pool_id: Optional[str] = None
    cognito_region: Optional[str] = None
    user_id: Optional[str] = None
    bvn: Optional[str] = None
    verification_type: str = "ONBOARDING"
    channel: Optional[str] = "personal"

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
    provider: str = Field("unknown", description="Liveness provider used, e.g. aws_rekognition or mock_provider")

class SessionDetailResponse(BaseModel):
    session_id: str
    user_id: Optional[str]
    bvn: Optional[str]
    channel: Optional[str]
    verification_type: str
    face_match_status: Optional[str] = None
    face_match_confidence: Optional[float] = None
    provider: str
    liveness_mode: str
    status: str
    confidence: float
    image_reference: Optional[str]
    video_reference: Optional[str]
    device_intelligence: Optional[str]
    created_at: float
    updated_at: float

    class Config:
        from_attributes = True

class SessionListResponse(BaseModel):
    total: int
    limit: int
    offset: int
    sessions: List[SessionDetailResponse]

class CustomerCreateRequest(BaseModel):
    bvn: str
    email: str
    phone: str
    channel: str = Field("personal", description="personal or business channel")

class CustomerCreateResponse(BaseModel):
    customer_id: str
    bvn: str
    email: str
    phone: str
    channel: str
    created_at: float

# --- Endpoints ---

@router.post(
    "/customer",
    response_model=CustomerCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Onboarding Customer Record",
    description="Registers a new customer profile with BVN, email, phone, and channel during onboarding."
)
async def create_customer(
    payload: CustomerCreateRequest,
    db: Session = Depends(get_db)
):
    # Check if BVN is exactly 11 digits
    if not payload.bvn.isdigit() or len(payload.bvn) != 11:
        raise HTTPException(status_code=400, detail="Invalid BVN. Must be exactly 11 numeric digits.")
    
    # Check channel options
    if payload.channel not in ["personal", "business"]:
        raise HTTPException(status_code=400, detail="Invalid channel. Must be 'personal' or 'business'.")
    
    # Check unique constraint on (bvn, channel)
    existing_customer = db.query(Customer).filter(
        Customer.bvn == payload.bvn,
        Customer.channel == payload.channel
    ).first()
    
    if existing_customer:
        # Check if there is any successful liveness session for this customer
        successful_session = db.query(LivenessSession).filter(
            LivenessSession.user_id == existing_customer.customer_id,
            LivenessSession.status == "PASS"
        ).first()
        
        if successful_session:
            raise HTTPException(
                status_code=400,
                detail=f"Customer with this BVN is already onboarded on the '{payload.channel}' channel."
            )
        else:
            # No successful onboarding completed yet. Allow retry by returning existing customer details.
            logger.info(f"Customer {existing_customer.customer_id} retrying onboarding on channel {payload.channel}.")
            return CustomerCreateResponse(
                customer_id=existing_customer.customer_id,
                bvn=existing_customer.bvn,
                email=existing_customer.email,
                phone=existing_customer.phone,
                channel=existing_customer.channel,
                created_at=existing_customer.created_at
            )
    
    # Create unique customer id as pure UUID string
    import uuid
    customer_id = str(uuid.uuid4())
    
    db_customer = Customer(
        customer_id=customer_id,
        bvn=payload.bvn,
        email=payload.email,
        phone=payload.phone,
        channel=payload.channel
    )
    db.add(db_customer)
    db.commit()
    db.refresh(db_customer)
    
    return CustomerCreateResponse(
        customer_id=db_customer.customer_id,
        bvn=db_customer.bvn,
        email=db_customer.email,
        phone=db_customer.phone,
        channel=db_customer.channel,
        created_at=db_customer.created_at
    )

@router.post(
    "/session",
    response_model=SessionCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Liveness Session",
    description="Initiates a new face liveness verification session with AWS Rekognition or alternative providers."
)
async def create_session(
    preferred_mode: Optional[str] = None,
    user_id: Optional[str] = None,
    bvn: Optional[str] = None,
    verification_type: str = "ONBOARDING",
    channel: str = "personal",
    service: LivenessService = Depends(get_liveness_service),
    db: Session = Depends(get_db)
):
    # Validate verification type & channel
    if verification_type not in ["ONBOARDING", "VERIFICATION"]:
        raise HTTPException(status_code=400, detail="Invalid verification_type. Must be 'ONBOARDING' or 'VERIFICATION'.")
    if channel not in ["personal", "business"]:
        raise HTTPException(status_code=400, detail="Invalid channel. Must be 'personal' or 'business'.")

    try:
        session_info = service.create_session(preferred_mode=preferred_mode)
        session_id = session_info["session_id"]
        provider = session_info["provider"]
        mode = session_info["liveness_mode"]
        
        # Save session to Postgres database
        db_session = LivenessSession(
            session_id=session_id,
            user_id=user_id,
            bvn=bvn,
            channel=channel,
            verification_type=verification_type,
            provider=provider,
            liveness_mode=mode,
            status="CREATED",
            confidence=0.0
        )
        db.add(db_session)
        db.commit()

        is_aws = provider == "aws_rekognition"
        return SessionCreateResponse(
            session_id=session_id,
            provider=provider,
            status="CREATED",
            liveness_mode=mode,
            cognito_pool_id=settings.COGNITO_POOL_ID if is_aws else None,
            cognito_region=settings.COGNITO_REGION if is_aws else None,
            user_id=user_id,
            bvn=bvn,
            verification_type=verification_type,
            channel=channel
        )
    except Exception as e:
        logger.error(f"Failed to create liveness session: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create session: {str(e)}"
        )


def parse_s3_uri(s3_uri: str):
    if not s3_uri.startswith("s3://"):
        raise ValueError("Invalid S3 URI: must start with s3://")
    parts = s3_uri[5:].split("/", 1)
    if len(parts) < 2:
        raise ValueError("Invalid S3 URI: missing key name")
    return parts[0], parts[1]

@router.post(
    "/verify",
    response_model=VerifySessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify Liveness Session",
    description="Retrieves the verification results, evaluates fraud rules, and logs device intelligence metadata."
)
async def verify_session(
    payload: VerifySessionRequest,
    service: LivenessService = Depends(get_liveness_service),
    db: Session = Depends(get_db)
):
    try:
        device_intel_str = ""
        if payload.device_intelligence:
            telemetry = payload.device_intelligence
            logger.info(
                f"[Audit Log] Verification Session: {payload.session_id} | "
                f"DeviceID: {telemetry.device_id} | Model: {telemetry.device_model} | "
                f"OS: {telemetry.device_os} | IP: {telemetry.ip_address} | "
                f"Coords: ({telemetry.latitude}, {telemetry.longitude})"
            )
            device_intel_str = json.dumps(telemetry.model_dump())
        else:
            logger.warning(f"[Audit Log] Verification Session: {payload.session_id} - No Device Intelligence data provided")

        # Query provider verification results
        result = service.verify_session(payload.session_id)
        
        # Update session outcomes in the Postgres database
        db_session = db.query(LivenessSession).filter(LivenessSession.session_id == payload.session_id).first()
        if db_session:
            db_session.status = result["status"]
            db_session.confidence = result["confidence"]
            db_session.image_reference = result.get("image_reference") or ""
            db_session.device_intelligence = device_intel_str
            
            # Post-processing liveness success logic
            if result["status"] in ["PASS", "MEDIUM_RISK"]:
                if db_session.verification_type == "ONBOARDING":
                    # Store the reference face on the customer record
                    if db_session.user_id:
                        customer = db.query(Customer).filter(Customer.customer_id == db_session.user_id).first()
                        if customer and not customer.reference_image_path:
                            customer.reference_image_path = result.get("image_reference") or ""
                            logger.info(f"Registered reference face path for customer {customer.customer_id}: {customer.reference_image_path}")
                
                elif db_session.verification_type == "VERIFICATION":
                    # Perform face comparison against customer's reference face
                    if db_session.user_id:
                        customer = db.query(Customer).filter(Customer.customer_id == db_session.user_id).first()
                        if not customer or not customer.reference_image_path:
                            logger.warning(f"Verification session failed: customer {db_session.user_id} has no reference face registered.")
                            db_session.face_match_status = "MISMATCH"
                            db_session.face_match_confidence = 0.0
                            db_session.status = "FAIL"
                        else:
                            # We have a customer and reference face image path
                            is_mock = settings.MOCK_AWS or db_session.provider in ["mock_provider", "google_ml_kit"]
                            if is_mock:
                                # Mock face comparison
                                if db_session.user_id.endswith("mismatch"):
                                    db_session.face_match_status = "MISMATCH"
                                    db_session.face_match_confidence = 42.1
                                    db_session.status = "FAIL"
                                    logger.info(f"Simulating face mismatch for user {db_session.user_id}")
                                else:
                                    db_session.face_match_status = "MATCH"
                                    db_session.face_match_confidence = 98.2
                                    logger.info(f"Simulating face match for user {db_session.user_id}")
                            else:
                                # Live AWS Rekognition face comparison
                                try:
                                    ref_bucket, ref_key = parse_s3_uri(customer.reference_image_path)
                                    src_bucket, src_key = parse_s3_uri(result.get("image_reference") or "")
                                    
                                    # Setup boto3 Rekognition client
                                    session_kwargs = {"region_name": settings.AWS_REGION}
                                    if settings.AWS_ACCESS_KEY_ID and settings.AWS_SECRET_ACCESS_KEY:
                                        session_kwargs["aws_access_key_id"] = settings.AWS_ACCESS_KEY_ID
                                        session_kwargs["aws_secret_access_key"] = settings.AWS_SECRET_ACCESS_KEY
                                    
                                    rek_client = boto3.client("rekognition", **session_kwargs)
                                    comp_resp = rek_client.compare_faces(
                                        SourceImage={'S3Object': {'Bucket': src_bucket, 'Name': src_key}},
                                        TargetImage={'S3Object': {'Bucket': ref_bucket, 'Name': ref_key}},
                                        SimilarityThreshold=90.0
                                    )
                                    
                                    face_matches = comp_resp.get("FaceMatches", [])
                                    if face_matches:
                                        match_confidence = float(face_matches[0]["Similarity"])
                                        db_session.face_match_status = "MATCH"
                                        db_session.face_match_confidence = match_confidence
                                        logger.info(f"AWS Face match succeeded: {match_confidence}% similarity.")
                                    else:
                                        db_session.face_match_status = "MISMATCH"
                                        db_session.face_match_confidence = 0.0
                                        db_session.status = "FAIL"
                                        logger.warning(f"AWS Face mismatch for user {db_session.user_id}.")
                                except Exception as comp_err:
                                    logger.error(f"Failed to compare faces using AWS Rekognition: {str(comp_err)}")
                                    db_session.face_match_status = "MISMATCH"
                                    db_session.face_match_confidence = 0.0
                                    db_session.status = "FAIL"
            
            db.commit()
        
        return VerifySessionResponse(
            status=db_session.status if db_session else result["status"],
            confidence=db_session.confidence if db_session else result["confidence"],
            provider_session_id=result["session_id"],
            timestamp=result["timestamp"],
            image_reference=result.get("image_reference"),
            provider=result.get("provider", "unknown")
        )
    except Exception as e:
        logger.error(f"Failed to verify liveness session {payload.session_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify session: {str(e)}"
        )


@router.get(
    "/sessions",
    response_model=SessionListResponse,
    summary="List Liveness Sessions (Admin only)",
    description="Returns a paginated list of liveness check audits. Supports searching by user_id and session_id."
)
async def list_sessions(
    limit: int = 10,
    offset: int = 0,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(LivenessSession)
    if search:
        query = query.filter(
            (LivenessSession.user_id.ilike(f"%{search}%")) |
            (LivenessSession.session_id.ilike(f"%{search}%")) |
            (LivenessSession.bvn.ilike(f"%{search}%"))
        )
    
    total = query.count()
    sessions = query.order_by(LivenessSession.created_at.desc()).offset(offset).limit(limit).all()
    
    return SessionListResponse(
        total=total,
        limit=limit,
        offset=offset,
        sessions=sessions
    )


@router.post(
    "/session/{session_id}/video/upload",
    summary="Upload custom liveness video directly to S3",
    description="Accepts liveness capture video upload from mobile SDK and stores it directly on S3 bucket."
)
async def upload_session_video(
    session_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    try:
        db_session = db.query(LivenessSession).filter(LivenessSession.session_id == session_id).first()
        if not db_session:
            raise HTTPException(status_code=404, detail="Liveness session not found")

        content = await file.read()
        
        # Upload strictly to S3
        s3_key = f"custom-liveness-videos/{session_id}.mp4"
        logger.info(f"Uploading liveness video for {session_id} to S3 bucket: {settings.LIVENESS_BUCKET}")
        
        s3_client = boto3.client(
            "s3",
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION
        )
        
        s3_client.put_object(
            Bucket=settings.LIVENESS_BUCKET,
            Key=s3_key,
            Body=content,
            ContentType="video/mp4"
        )
        
        db_session.video_reference = f"s3://{settings.LIVENESS_BUCKET}/{s3_key}"
        db.commit()
        
        return {"status": "success", "video_reference": db_session.video_reference}
    except Exception as e:
        logger.error(f"Failed to upload video for session {session_id}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to upload video: {str(e)}"
        )


@router.get(
    "/session/{session_id}/video",
    summary="Generate S3 presigned URL for liveness session replay (Admin only)",
    description="Locates the session video key on S3 (works for both AWS native streams and custom uploads) and returns a secure presigned replay URL."
)
async def get_session_video_url(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_session = db.query(LivenessSession).filter(LivenessSession.session_id == session_id).first()
    if not db_session:
        raise HTTPException(status_code=404, detail="Liveness session not found")

    s3_client = boto3.client(
        "s3",
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        region_name=settings.AWS_REGION
    )

    bucket = None
    key = None

    # Case A: Custom Google ML Kit / Mock video upload
    if db_session.video_reference and db_session.video_reference.startswith("s3://"):
        path = db_session.video_reference.replace("s3://", "")
        parts = path.split("/", 1)
        bucket = parts[0]
        key = parts[1]
    else:
        # Case B: AWS Rekognition dynamic stream.
        # AWS automatically deposits this under AWS-Rekognition-Liveness-Session-Video/{session_id}/
        try:
            prefix = f"AWS-Rekognition-Liveness-Session-Video/{session_id}/"
            response = s3_client.list_objects_v2(
                Bucket=settings.LIVENESS_BUCKET,
                Prefix=prefix
            )
            contents = response.get("Contents", [])
            if contents:
                bucket = settings.LIVENESS_BUCKET
                key = contents[0]["Key"]
            else:
                raise HTTPException(status_code=404, detail="Replay video not found on S3. Wait a moment or check configuration.")
        except Exception as e:
            if isinstance(e, HTTPException):
                raise e
            logger.error(f"Error listing S3 objects for session {session_id}: {str(e)}")
            raise HTTPException(status_code=404, detail="Failed to locate session video on S3")

    # Generate the S3 Pre-signed URL (valid for 1 hour)
    try:
        presigned_url = s3_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=3600
        )
        return {"url": presigned_url}
    except Exception as e:
        logger.error(f"Error generating presigned S3 URL: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to generate playback URL")
