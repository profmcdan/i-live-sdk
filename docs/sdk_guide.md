# SDK Integration Guide (Flutter)

A developer handbook for integrating the FaceGuard liveness verification package.

---

## 1. Project Integration

### Dependencies
In your app's `pubspec.yaml`, link the package:
```yaml
dependencies:
  kolomoni_liveness_sdk:
    path: packages/liveness_sdk
```

### Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.front" />
```

### iOS Configuration
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<key>This app requires camera access to perform biometric face liveness checks during verification actions.</key>
```

---

## 2. SDK Initialization
Initialize the SDK once during application startup (e.g., inside `main.dart`):

```dart
import 'package:kolomoni_liveness_sdk/kolomoni_liveness_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await LivenessSDK.initialize(
    backendUrl: 'https://api.staging.faceguard.com',
    apiKey: 'your-app-api-key',
    environment: LivenessEnvironment.staging,
    timeoutSeconds: 15,
  );

  runApp(const MyApp());
}
```

---

## 3. Launching Verification
Call `LivenessSDK.verify(context)` when intercepting secure flows.

### Example: Onboarding Verification
```dart
void onOnboardingTriggered(BuildContext context) async {
  // 1. Launch liveness scanning interface
  final result = await LivenessSDK.verify(
    context,
    userId: 'customer-uuid-created-on-backend',
    bvn: '11122233344',
    verificationType: 'ONBOARDING',
    channel: 'personal',
  );

  if (!result.success) {
    showErrorBlock('Biometric verification failed.');
    return;
  }

  proceedWithRegistration();
}
```

### Example: Face Verification Check (No BVN required)
```dart
void onFaceVerificationTriggered(BuildContext context, String customerId, String channel) async {
  final result = await LivenessSDK.verify(
    context,
    userId: customerId,
    verificationType: 'VERIFICATION',
    channel: channel,
  );

  if (!result.success) {
    showErrorBlock('Face Match comparison failed. Access blocked.');
    return;
  }

  proceedWithTransaction();
}
```

---

## 4. Customizing Verification Providers and Modes (API Configured)
The liveness verification provider and challenges adapt dynamically based on backend configurations.

### Active Provider Options
Configure `LIVENESS_PROVIDER` in your backend `.env` settings:
- `aws_rekognition`: Stream real-time camera frames to AWS Rekognition using Cognito Identity pools.
- `google_ml_kit`: Run on-device face and gesture detection with Google ML Kit.
- `mock_provider`: Simulated capture for local testing.

---

## 5. Running the Example App on Android (Step-by-Step)

### Step 1: Start the Backend Server
Ensure your backend FastAPI server is running locally (using Docker Compose).
By default, the server runs on `http://localhost:8000`.

### Step 2: Configure Android Network Loopback
* **Android Emulator**: In the example application UI, configure the Backend URL text field to `http://10.0.2.2:8000`.
* **Physical Android Device**: Connect both the host machine and the Android device to the same Wi-Fi network. Find the host machine's local IP address (e.g. `192.168.1.50`) and configure the backend URL in the app to `http://192.168.1.50:8000`.

### Step 3: Connect Your Device / Launch Emulator
* Verify your device is connected:
  ```bash
  flutter devices
  ```

### Step 4: Install Dependencies & Run
1. Navigate to the example directory:
   ```bash
   cd example
   ```
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 6. Troubleshooting

### Emulator Camera displays blurred colors or Virtual Scene
By default, the Android Emulator's camera is configured to render a 3D "Virtual Scene". Because this virtual feed contains no real human face, liveness checks will time out or fail.

To resolve this during testing:
1. **Configure Mock Mode**:
   Set `LIVENESS_PROVIDER=mock_provider` in the backend `.env` file and restart the API server. This instructs the SDK to route liveness checks through a simulated interactive UI.
2. **Real Webcam Integration**:
   * Open the **Android Studio Device Manager**.
   * Edit your active virtual device, click **Show Advanced Settings**, scroll to the **Camera** section.
   * Change the **Front** camera from `VirtualScene` to `Webcam0` (your computer's built-in webcam) and restart.
