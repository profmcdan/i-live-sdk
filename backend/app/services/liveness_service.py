import abc
import logging
import uuid
import time
from typing import Dict, Any, Tuple, Optional
import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.config import settings

logger = logging.getLogger(__name__)

class LivenessService(abc.ABC):
    @abc.abstractmethod
    def create_session(self, preferred_mode: Optional[str] = None) -> Dict[str, Any]:
        """
        Creates a new Face Liveness session.
        Returns:
            Dict containing session_id and other provider metadata.
        """
        pass

    @abc.abstractmethod
    def verify_session(self, session_id: str) -> Dict[str, Any]:
        """
        Retrieves the result of a Face Liveness session.
        Returns:
            Dict containing status (PASS, FAIL, LOW_CONFIDENCE, etc.), confidence score, and audit details.
        """
        pass


class AwsRekognitionService(LivenessService):
    def __init__(self):
        # Initialize boto3 Rekognition client
        session_kwargs = {
            "region_name": settings.AWS_REGION
        }
        if settings.AWS_ACCESS_KEY_ID and settings.AWS_SECRET_ACCESS_KEY:
            session_kwargs["aws_access_key_id"] = settings.AWS_ACCESS_KEY_ID
            session_kwargs["aws_secret_access_key"] = settings.AWS_SECRET_ACCESS_KEY
            
        self.client = boto3.client("rekognition", **session_kwargs)

    def create_session(self, preferred_mode: Optional[str] = None) -> Dict[str, Any]:
        try:
            logger.info("Creating AWS Rekognition Face Liveness Session")
            # Create session payload
            params = {}
            if settings.LIVENESS_BUCKET:
                params["Settings"] = {
                    "OutputConfig": {
                        "S3Bucket": settings.LIVENESS_BUCKET
                    }
                }
            
            response = self.client.create_face_liveness_session(**params)
            session_id = response.get("SessionId")
            logger.info(f"Successfully created AWS Rekognition Session: {session_id}")
            
            # Resolve liveness mode config
            valid_modes = ["PASSIVE", "ACTIVE", "PASSIVE_WITH_ACTIVE_FALLBACK"]
            mode = preferred_mode if preferred_mode in valid_modes else settings.DEFAULT_LIVENESS_MODE

            return {
                "session_id": session_id,
                "provider": "aws_rekognition",
                "status": "CREATED",
                "liveness_mode": mode,
                "created_at": time.time()
            }
        except (BotoCoreError, ClientError) as e:
            logger.error(f"Error creating AWS Face Liveness session: {str(e)}")
            raise RuntimeError(f"AWS Rekognition Error: {str(e)}")

    def verify_session(self, session_id: str) -> Dict[str, Any]:
        try:
            logger.info(f"Retrieving AWS Rekognition Liveness results for session: {session_id}")
            response = self.client.get_face_liveness_session_results(SessionId=session_id)
            
            status = response.get("Status")  # e.g., SUCCEEDED, FAILED, EXPIRED, IN_PROGRESS
            confidence = response.get("Confidence", 0.0)
            
            # Extract image reference if available
            reference_image = None
            if "ReferenceImage" in response and "S3Object" in response["ReferenceImage"]:
                s3_obj = response["ReferenceImage"]["S3Object"]
                reference_image = f"s3://{s3_obj.get('Bucket')}/{s3_obj.get('Name')}"

            logger.info(f"AWS session {session_id} returned status={status}, confidence={confidence}")
            
            # Map status and confidence based on fraud decision rules
            if status == "SUCCEEDED":
                if confidence >= settings.LIVENESS_PASS_THRESHOLD:
                    verification_status = "PASS"
                elif confidence >= settings.LIVENESS_MEDIUM_RISK_THRESHOLD:
                    verification_status = "MEDIUM_RISK"
                else:
                    verification_status = "LOW_CONFIDENCE"
            elif status == "EXPIRED":
                verification_status = "TIMEOUT"
            elif status == "FAILED":
                verification_status = "FAIL"
            else:
                verification_status = "IN_PROGRESS"
                
            return {
                "session_id": session_id,
                "status": verification_status,
                "confidence": float(confidence),
                "provider": "aws_rekognition",
                "image_reference": reference_image or "",
                "raw_status": status,
                "timestamp": time.time()
            }
        except (BotoCoreError, ClientError) as e:
            logger.error(f"Error getting AWS Face Liveness results for {session_id}: {str(e)}")
            raise RuntimeError(f"AWS Rekognition Error: {str(e)}")


class MockLivenessService(LivenessService):
    """
    Mock service to test the entire client-server workflow locally without AWS resources.
    """
    def __init__(self):
        # In-memory session store
        self._sessions: Dict[str, Dict[str, Any]] = {}

    def create_session(self, preferred_mode: Optional[str] = None) -> Dict[str, Any]:
        session_id = f"mock_session_{uuid.uuid4().hex[:12]}"
        logger.info(f"Creating MOCK Liveness Session: {session_id}")
        
        valid_modes = ["PASSIVE", "ACTIVE", "PASSIVE_WITH_ACTIVE_FALLBACK"]
        mode = preferred_mode if preferred_mode in valid_modes else settings.DEFAULT_LIVENESS_MODE

        session_data = {
            "session_id": session_id,
            "provider": "mock_provider",
            "status": "CREATED",
            "liveness_mode": mode,
            "created_at": time.time()
        }
        self._sessions[session_id] = session_data
        return session_data

    def verify_session(self, session_id: str) -> Dict[str, Any]:
        logger.info(f"Verifying MOCK Liveness Session: {session_id}")
        
        if session_id not in self._sessions:
            logger.warning(f"Session {session_id} not found in Mock store. Simulating standard response.")
            # For demonstration, allow any valid-looking mock session ID to pass
            if session_id.startswith("mock_session_"):
                confidence = 98.7
                status = "PASS"
            else:
                return {
                    "session_id": session_id,
                    "status": "FAIL",
                    "confidence": 0.0,
                    "provider": "mock_provider",
                    "image_reference": "",
                    "timestamp": time.time(),
                    "error": "Session not found"
                }
        else:
            session = self._sessions[session_id]
            # Determine mock outcome based on session_id suffix for testing different scenarios
            # End with 'fail' for FAIL, 'low' for LOW_CONFIDENCE, otherwise PASS
            if session_id.endswith("fail"):
                confidence = 45.2
                status = "FAIL"
            elif session_id.endswith("low"):
                confidence = 88.5
                status = "LOW_CONFIDENCE"
            else:
                confidence = 98.7
                status = "PASS"
                
        return {
            "session_id": session_id,
            "status": status,
            "confidence": confidence,
            "provider": "mock_provider",
            "image_reference": f"mock://storage/{session_id}_ref.jpg",
            "timestamp": time.time()
        }


def get_liveness_service() -> LivenessService:
    """Dependency injection factory for LivenessService"""
    if settings.MOCK_AWS:
        logger.info("Initializing Mock Liveness Service")
        return MockLivenessService()
    else:
        logger.info("Initializing AWS Rekognition Liveness Service")
        return AwsRekognitionService()
