# Kolomoni Biometric Liveness Verification SDK & API

A production-grade, enterprise-ready biometric liveness verification solution designed for CST Group applications (including Kolomoni Personal Banking, Business Banking, and Agency Banking). This repository contains both a **reusable Flutter Liveness SDK** and a **FastAPI backend** that aggregates and validates AWS Rekognition Face Liveness sessions.

---

## Repository Structure

```tree
.
├── README.md               # Central entrypoint and quickstart guide
├── docs/                   # In-depth design & integration documentation
│   ├── architecture.md     # Architecture designs & transaction flows
│   ├── api_reference.md    # API contracts (Backend endpoints & Dart classes)
│   ├── security.md         # Data protection (NDPA/GDPR), anti-tampering & encryption
│   ├── sdk_guide.md        # SDK configuration and usage handbook for developers
│   └── aws_setup.md        # AWS Rekognition & S3 console setup checklist
├── backend/                # FastAPI backend API
│   ├── app/                # Application module (config, routers, services)
│   ├── Dockerfile          # Multi-stage Docker deployment setup
│   ├── docker-compose.yml  # Docker Compose script for local development/testing
│   └── run.sh              # Direct run command script
├── liveness_sdk/           # Reusable Flutter Liveness Verification SDK Package
│   ├── lib/                # SDK classes & UI views
│   └── pubspec.yaml        # SDK package configuration
└── example/                # Demo Flutter app showing multi-use case integration
    ├── lib/
    └── pubspec.yaml
```

---

## Key Features

1. **Anti-Spoof Defense**: Supports passive and active challenge fallbacks to prevent screen replay, deepfakes, printed/synthetic media attacks, etc.
2. **Provider Abstraction**: A decoupled Flutter architecture allows swapping backend liveness engines (AWS Rekognition, FaceTec, iProov, Jumio) dynamically without changes to downstream banking clients.
3. **Device Intelligence Integration**: Collects device models, coordinates, IP addresses, and tamper signatures alongside session verification to feed the Fraud Detection Engine.
4. **Mock Testing Mode**: Start development immediately! Supports simulated liveness audits on both frontend and backend for testing without active AWS credentials or camera hardware.

---

## FastAPI Backend Startup Guide

### Prerequisites
- Python 3.10+ (for running locally)
- Docker & Docker Compose (for containerized setup)

### Running with Docker Compose (Recommended)
By default, Docker Compose spins up the backend in **Mock mode** (`MOCK_AWS=true`).
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Start the service:
   ```bash
   docker-compose up --build
   ```
3. The API will be available at `http://localhost:8000`. You can inspect the interactive OpenAPI spec at `http://localhost:8000/docs`.

### Running Locally without Docker
1. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Execute the runner script:
   ```bash
   ./run.sh
   ```

### AWS Rekognition Setup
To configure production credentials:
1. Create a `.env` file inside `backend/`:
   ```env
   MOCK_AWS=false
   AWS_ACCESS_KEY_ID=your_access_key
   AWS_SECRET_ACCESS_KEY=your_secret_key
   AWS_REGION=us-east-1
   LIVENESS_BUCKET=your-liveness-audit-s3-bucket
   ```
2. Re-run with `docker-compose up` or `./run.sh`.

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
  forceMockMode: false, // Set to true to test without a running backend
);

// Trigger a check during high-risk events (e.g. Transfers, PIN Reset)
final result = await LivenessSDK.verify(context);

if (result.success) {
  print('Authorized! Confidence: ${result.confidence}%');
  // Proceed with transaction...
} else {
  print('Blocked: ${result.errorMessage}');
  // Show error screen...
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
