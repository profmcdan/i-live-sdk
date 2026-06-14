# API Reference Specification

This reference guide documents the API contracts for the FaceGuard Backend REST endpoints and the Flutter SDK library.

---

## 1. FastAPI Backend API

### Create Onboarding Customer Record
Registers a new customer profile before liveness check.

* **Endpoint**: `/api/v1/liveness/customer`
* **Method**: `POST`
* **Content-Type**: `application/json`
* **Response Status**: `201 Created`

#### Request Payload
```json
{
  "bvn": "11122233344",
  "email": "cust@example.com",
  "phone": "+2348000000000",
  "channel": "personal"
}
```

#### Response Body
```json
{
  "customer_id": "f5165d4b-df73-4ea2-bc89-183063bd70b1",
  "bvn": "11122233344",
  "email": "cust@example.com",
  "phone": "+2348000000000",
  "channel": "personal",
  "created_at": 1718293860.12
}
```

---

### Initialize Liveness Session
Creates a liveness session configuration tracker.

* **Endpoint**: `/api/v1/liveness/session`
* **Method**: `POST`
* **Query Parameters**:
  * `preferred_mode` (Optional, string): e.g. `ACTIVE` or `PASSIVE`
  * `user_id` (Optional, string): Customer UUID string
  * `bvn` (Optional, string): 11-digit BVN
  * `verification_type` (Optional, string): `ONBOARDING` or `VERIFICATION`
  * `channel` (Optional, string): `personal` or `business`
* **Response Status**: `201 Created`

#### Response Body
```json
{
  "session_id": "371baebd-d87a-4a89-9681-10888e5420b9",
  "provider": "google_ml_kit",
  "status": "CREATED",
  "liveness_mode": "PASSIVE_WITH_ACTIVE_FALLBACK",
  "user_id": "f5165d4b-df73-4ea2-bc89-183063bd70b1",
  "bvn": "11122233344",
  "verification_type": "ONBOARDING",
  "channel": "personal"
}
```

---

### Upload Session Video
Accepts and stores liveness verification video on S3.

* **Endpoint**: `/api/v1/liveness/session/{session_id}/video/upload`
* **Method**: `POST`
* **Content-Type**: `multipart/form-data`
* **Response Status**: `200 OK`

---

### Get Replay URL (Admin only)
Generates S3 presigned URL for playback.

* **Endpoint**: `/api/v1/liveness/session/{session_id}/video`
* **Method**: `GET`
* **Headers**: `Authorization: Bearer <JWT_Token>`
* **Response Body**:
```json
{
  "url": "https://faceguard-liveness-bucket.s3.amazonaws.com/custom-liveness-videos/..."
}
```

---

### List Liveness Sessions (Admin only)
Returns paginated log table records.

* **Endpoint**: `/api/v1/liveness/sessions`
* **Method**: `GET`
* **Headers**: `Authorization: Bearer <JWT_Token>`
* **Query Parameters**: `limit`, `offset`, `search`
* **Response Body**:
```json
{
  "total": 12,
  "limit": 10,
  "offset": 0,
  "sessions": [
    {
      "session_id": "371baebd-d87a-4a89-9681-10888e5420b9",
      "user_id": "f5165d4b-df73-4ea2-bc89-183063bd70b1",
      "bvn": "11122233344",
      "channel": "personal",
      "verification_type": "ONBOARDING",
      "face_match_status": "MATCH",
      "face_match_confidence": 98.2,
      "provider": "google_ml_kit",
      "liveness_mode": "PASSIVE",
      "status": "PASS",
      "confidence": 99.4,
      "image_reference": "s3://bucket/ref.jpg",
      "video_reference": "s3://bucket/vid.mp4",
      "device_intelligence": "{...}",
      "created_at": 1718293860.12,
      "updated_at": 1718293870.44
    }
  ]
}
```

---

## 2. Flutter SDK Class Interface

### `LivenessSDK` Class

#### `initialize` static method
```dart
static Future<void> initialize({
  required String backendUrl,
  String apiKey = '',
  LivenessEnvironment environment = LivenessEnvironment.development,
  int maxRetries = 3,
  bool activeFallbackEnabled = true,
  int timeoutSeconds = 15,
  double passThreshold = 95.0,
  bool forceMockMode = false,
})
```

#### `verify` static method
```dart
static Future<LivenessResult> verify(
  BuildContext context, {
  String? userId,
  String? bvn,
  String? verificationType,
  String? channel,
})
```

---

### `LivenessResult` Class

| Field | Type | Description |
|---|---|---|
| `success` | `bool` | True if verification succeeded (`PASS` or `MEDIUM_RISK`). |
| `status` | `LivenessStatus` | Enum mapping the verification category result. |
| `confidence` | `double` | Mathematical confidence score returned by backend (0.0 - 100.0). |
| `sessionId` | `String` | Unique Session ID associated with this verification audit. |
| `provider` | `String` | Identifying string of the engine provider (e.g. `aws_rekognition`). |
| `imageReference` | `String` | Remote S3 URI referencing the saved audit frame. |
| `errorMessage` | `String?` | Non-null description of failure if liveness verification failed. |
| `timestamp` | `DateTime` | Timestamp of the event execution. |
