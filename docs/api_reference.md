# API Reference Specification

This reference guide documents the API contracts for the FastAPI Backend REST endpoints and the Flutter SDK library.

---

## 1. FastAPI Backend API

### Initialize Liveness Session
Creates a unique session tracker in AWS Rekognition.

* **Endpoint**: `/api/v1/liveness/session`
* **Method**: `POST`
* **Content-Type**: `application/json`
* **Response Status**: `201 Created`

#### Request Payload
*(None)*

#### Response Body
```json
{
  "session_id": "mock_session_e90f23d11b5a",
  "provider": "mock_provider",
  "status": "CREATED"
}
```

#### Example Curl
```bash
curl -X POST http://localhost:8000/api/v1/liveness/session \
  -H "Content-Type: application/json"
```

---

### Verify Liveness Session
Submits a liveness session for validation, collects telemetry logs, and returns the authentication decision.

* **Endpoint**: `/api/v1/liveness/verify`
* **Method**: `POST`
* **Content-Type**: `application/json`
* **Response Status**: `200 OK`

#### Request Body
```json
{
  "session_id": "mock_session_e90f23d11b5a",
  "device_intelligence": {
    "device_id": "dev_id_1718293848",
    "device_model": "iPhone 15 Pro",
    "device_os": "iOS 17.2",
    "ip_address": "192.168.1.1",
    "latitude": "6.5244",
    "longitude": "3.3792"
  }
}
```

#### Response Body
```json
{
  "status": "PASS",
  "confidence": 98.7,
  "provider_session_id": "mock_session_e90f23d11b5a",
  "timestamp": 1718293860.12,
  "image_reference": "mock://reference_images/face_audit_mock.jpg"
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
static Future<LivenessResult> verify(BuildContext context)
```

---

### `LivenessResult` Class

Representing the output details of a liveness run:

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

---

### `LivenessStatus` Enum

* `LivenessStatus.pass`: Match confidence meets or exceeds `95%`.
* `LivenessStatus.mediumRisk`: Match confidence between `80% - 94%`. Triggers secondary authentication (e.g., OTP).
* `LivenessStatus.lowConfidence`: Match confidence below `80%`. High risk of spoofing. Action blocked.
* `LivenessStatus.fail`: Face validation check failed.
* `LivenessStatus.timeout`: Liveness execution exceeded session limit.
* `LivenessStatus.cameraDenied`: User refused or blocked camera permissions.
* `LivenessStatus.networkError`: Device failed to connect with verification backend API.
* `LivenessStatus.cancelled`: Process aborted by physical navigation/dismissal.
