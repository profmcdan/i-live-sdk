# FaceGuard Biometric Liveness Verification SDK & API

A production-grade, enterprise-ready biometric liveness verification solution designed for applications utilizing the FaceGuard biometric suite. This repository contains both a **reusable Flutter Liveness SDK** and a **FastAPI backend** that aggregates and validates AWS Rekognition and Google ML Kit Face Liveness sessions.

---

## Repository Structure

```tree
.
├── README.md               # Central entrypoint and quickstart guide
├── docs/                   # In-depth design & integration documentation
├── docs/architecture.md    # Architecture designs & transaction flows
├── docs/api_reference.md   # API contracts (Backend endpoints & Dart classes)
├── docs/security.md        # Data protection (NDPA/GDPR), anti-tampering & encryption
├── docs/sdk_guide.md       # SDK configuration and usage handbook for developers
├── docs/aws_setup.md       # AWS Rekognition & S3 console setup checklist
├── backend/                # FastAPI backend API
├── backend/app/            # Application module (config, routers, services, models)
├── backend/alembic/        # Alembic database schema migrations (Versions 001 - 003)
├── backend/Dockerfile      # Multi-stage Docker deployment setup
├── backend/docker-compose.yml # Docker Compose script for local development/testing
├── liveness_sdk/           # Reusable Flutter Liveness Verification SDK Package
└── example/                # Rebrand demo Flutter app showing multi-use case integration
```

---

## Key Features

1. **Anti-Spoof Defense**: Supports passive and active challenge fallbacks to prevent screen replay, deepfakes, printed/synthetic media attacks, etc.
2. **Provider Abstraction**: A decoupled Flutter architecture allows swapping backend liveness engines (AWS Rekognition, Google ML Kit, Mock) dynamically without changes to downstream client apps.
3. **Database Audit Logging**: Configured with PostgreSQL and managed using Alembic schema migrations. Stores session metadata, coordinates, and device intelligence.
4. **Interactive Security Dashboard**: FaceGuard Admin panel with real-time KPI metrics (Success Rate, Threats Blocked), trend charts, and secure S3 presigned URL video replays.
5. **Onboarding retry and segmentation**: Enforces Unique `(bvn, channel)` constraints with personal/business channel segmentation, allowing retries on failed check sessions.
6. **Advanced ML Kit Gestures**: Features eye-blink detection alongside head movements (Tilt Up, Tilt Down, Tilt Sideways).

---

## FastAPI Backend Startup Guide

### Prerequisites
- Python 3.10+ (for running locally)
- Docker & Docker Compose (for containerized setup)

### Running with Docker Compose (Recommended)
By default, Docker Compose spins up the backend, runs Alembic migrations, and boots the PostgreSQL DB container.
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Start the services:
   ```bash
   docker compose up --build
   ```
3. The API will be available at `http://localhost:8000`. You can inspect the interactive OpenAPI spec at `http://localhost:8000/docs`.

---

## Flutter SDK Quickstart

### 1. Installation
In your Flutter project's `pubspec.yaml`, add the SDK path:
```yaml
dependencies:
  kolomoni_liveness_sdk:
    path: path/to/liveness_sdk
```

### 2. Usage
```dart
import 'package:kolomoni_liveness_sdk/kolomoni_liveness_sdk.dart';

// Initialize on app start
await LivenessSDK.initialize(
  backendUrl: 'http://localhost:8000', // or your staging api
  environment: LivenessEnvironment.development,
);

// Trigger check
final result = await LivenessSDK.verify(
  context,
  userId: 'customer-uuid-here',
  verificationType: 'VERIFICATION',
  channel: 'personal',
);

if (result.success) {
  print('Authorized! Confidence: ${result.confidence}%');
} else {
  print('Blocked: ${result.errorMessage}');
}
```

---

## Detailed Guides
For detailed documentation on specific areas:
- 📊 **[Architecture Details](file:///Users/danielale/Documents/software-projects/ilive-sdk/docs/architecture.md)**
- 🔌 **[API Reference Specifications](file:///Users/danielale/Documents/software-projects/ilive-sdk/docs/api_reference.md)**
- 🔒 **[Security & Data Protection](file:///Users/danielale/Documents/software-projects/ilive-sdk/docs/security.md)**
- 📱 **[Developer SDK Integration Guide](file:///Users/danielale/Documents/software-projects/ilive-sdk/docs/sdk_guide.md)**
- ☁️ **[AWS Rekognition Setup Guide](file:///Users/danielale/Documents/software-projects/ilive-sdk/docs/aws_setup.md)**
