# Architectural Design - FaceGuard Biometric Liveness Verification

This document details the system components, database storage layer, data flows, and architectural decoupling mechanisms implemented in the FaceGuard Biometric Liveness solution.

---

## High-Level Component Relationship

```
┌───────────────┐         Method Invocation         ┌──────────────────────┐
│  Flutter App  │ ────────────────────────────────> │ Liveness SDK Package │
│  (Example UI)  │                                   └──────────────────────┘
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
                       │                  │
    Reads/Writes Audits│                  │ Boto3 Rekognition client calls
                       ▼                  ▼
             ┌───────────┐      ┌──────────────────────┐
             │Postgres DB│      │ AWS Rekognition/S3   │
             └───────────┘      └──────────────────────┘
```

---

## Detailed Sequence Flow

The process consists of two primary use cases: **Customer Onboarding** and **Account Face Verification**.

### A. Customer Onboarding Flow
1. **App** sends Customer details (BVN, email, phone, channel) to backend `POST /api/v1/liveness/customer`.
2. **Backend API** queries Postgres to check for existing onboarded customers with same `(bvn, channel)` unique key.
   * If a successful onboarding exists, returns `400 Bad Request` block.
   * If it doesn't exist, generates a new pure UUID `customer_id` and registers customer in database.
   * If registration exists but has failed previous checks, allows onboarding retry and returns existing `customer_id`.
3. **App** creates onboarding session (`POST /api/v1/liveness/session?verification_type=ONBOARDING&channel=x`).
4. **Backend** initializes Rekognition Liveness session and returns `session_id`.
5. **App** launches guided Camera UI (Google ML Kit gestures or AWS Cognito live streams), performs blink/tilt gestures, and records a 2.5-second video.
6. **App** uploads mp4 video to backend `POST /session/{session_id}/video/upload` (which uploads directly to S3) and calls `POST /verify`.
7. **Backend** queries liveness status. On liveness pass, saves the reference image URI as `customer.reference_image_path` in the Postgres database.
8. **Backend** returns onboarding success result.

### B. Account Face Verification Flow
1. **App** initializes verification session using only User ID and Channel (`POST /api/v1/liveness/session?verification_type=VERIFICATION&channel=x`).
2. **Backend** checks if customer exists and has a reference image on file. Returns `session_id`.
3. **App** captures user's face, uploads the mp4 video, and requests verify.
4. **Backend** fetches liveness outcome. On liveness pass, it performs **Face Comparison**:
   * **AWS Mode**: Compares reference S3 image path with the current session verification image path using AWS Rekognition `compare_faces`.
   * **Mock Mode**: Simulates comparison check based on customer ID formats.
5. If comparison similarity is below threshold (90%) or face mismatch is detected, session status is changed to `FAIL` and authentication is blocked.

---

## Decoupled Provider Abstraction Model

To avoid vendor lock-in with AWS Rekognition, the SDK isolates engine-specific logic behind a clean contract interface:

```dart
abstract class LivenessProvider {
  Future<void> initialize(LivenessConfig config);
  Future<LivenessResult> verify(
    BuildContext context, {
    String? userId,
    String? bvn,
    String? verificationType,
    String? channel,
  });
  bool get isInitialized;
}
```

The consumer application interacts only with the top-level `LivenessSDK` static interface. This design allows swapping the underlying implementation class from `AwsRekognitionLivenessProvider` to `GoogleMlKitLivenessProvider` or another vendor through configurations centrally on the backend API without changing any code in downstream mobile applications.
