# Architectural Design - Biometric Liveness Verification

This document details the system components, data flows, and architectural decoupling mechanisms implemented in the CST Biometric Liveness solution.

---

## High-Level Component Relationship

```
┌───────────────┐         Method Invocation         ┌──────────────────────┐
│  Flutter App  │ ────────────────────────────────> │ Liveness SDK Package │
└───────────────┘                                   └──────────────────────┘
        │                                                      │
        │                                                      │ Triggers
        │                                                      ▼
        │                                           ┌──────────────────────┐
        │                                           │ Liveness Camera View │
        │                                           └──────────────────────┘
        │                                                      │
        │ HTTP API Calls (Session / Verify)                    │ Streams video/frames
        └───────────────────────┬──────────────────────────────┘
                                │
                                ▼
                    ┌──────────────────────┐
                    │ FastAPI Backend API  │
                    └──────────────────────┘
                                │
                                │ Boto3 Rekognition client calls
                                ▼
                    ┌──────────────────────┐
                    │ AWS Rekognition Service
                    └──────────────────────┘
```

---

## Detailed Sequence Flow

The following sequence diagram represents the step-by-step process of creating a session, running the interactive guided camera scan, uploading frame telemetry, and verifying the liveness check against the fraud decision matrix.

```mermaid
sequenceDiagram
    autonumber
    participant App as Flutter App
    participant SDK as Liveness SDK
    participant API as FastAPI Backend
    participant AWS as AWS Rekognition

    App->>SDK: initialize(backendUrl, environment)
    Note over App,SDK: Ready for secure triggers
    
    App->>SDK: verify(context)
    SDK->>API: POST /api/v1/liveness/session
    API->>AWS: create_face_liveness_session()
    AWS-->>API: Response (SessionId)
    API-->>SDK: Response (session_id)
    
    SDK->>SDK: Launch Camera UI
    SDK->>SDK: Face Alignment Checks (Oval Frame overlay)
    SDK->>SDK: Record 2-5s video / frame sequence
    Note over SDK: Active gestures (like blinking) are triggered if required
    SDK->>SDK: Save video stream (transient temporary file)
    
    SDK->>API: POST /api/v1/liveness/verify (session_id, DeviceTelemetry)
    Note over API: Log telemetry for anti-tamper audits
    API->>AWS: get_face_liveness_session_results(SessionId)
    AWS-->>API: Response (Confidence, Status: SUCCEEDED)
    
    Note over API: Apply Decision Rules:<br/>Pass (>=95%)<br/>Medium (80-94%) -> OTP<br/>Fail (<80%) -> Block
    
    API-->>SDK: Verification Result (PASS / FAIL / MEDIUM_RISK)
    SDK->>SDK: Securely delete transient video files
    SDK-->>App: Return LivenessResult
    
    Note over App: Complete transaction or block/warn user
```

---

## Decoupled Provider Abstraction Model

To avoid vendor lock-in with AWS Rekognition, the SDK isolates engine-specific logic behind a clean contract interface:

```dart
abstract class LivenessProvider {
  Future<void> initialize(LivenessConfig config);
  Future<LivenessResult> verify(BuildContext context);
  bool get isInitialized;
}
```

The consumer application interacts only with the top-level `LivenessSDK` static interface. This design allows swapping the underlying implementation class from `AwsRekognitionLivenessProvider` to another vendor (e.g., `FaceTecLivenessProvider`, `iProovLivenessProvider`, or `JumioLivenessProvider`) through config updates without changing any code in downstream mobile applications.
