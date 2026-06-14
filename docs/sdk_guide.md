# SDK Integration Guide (Flutter)

A developer handbook for integrating the `kolomoni_liveness_sdk` package across CST Group applications.

---

## 1. Project Integration

### Dependencies
In your app's `pubspec.yaml`, link the local package:
```yaml
dependencies:
  kolomoni_liveness_sdk:
    path: packages/kolomoni_liveness_sdk
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
<string>This app requires camera access to perform biometric face liveness checks during verification actions.</string>
```

---

## 2. SDK Initialization
Initialize the SDK once during application startup (e.g., inside `main.dart`):

```dart
import 'package:kolomoni_liveness_sdk/kolomoni_liveness_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await LivenessSDK.initialize(
    backendUrl: 'https://api.staging.kolomoni.com',
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

### Example: High-Value Fund Transfer Verification
```dart
void onTransferTriggered(BuildContext context) async {
  // 1. Launch liveness scanning interface
  final result = await LivenessSDK.verify(context);

  if (!result.success) {
    // 2. Map block actions based on specific result status
    switch (result.status) {
      case LivenessStatus.cancelled:
        showNotification('Transfer cancelled by user');
        break;
      case LivenessStatus.lowConfidence:
        showErrorBlock('Security Block: Low liveness confidence detected.');
        break;
      case LivenessStatus.fail:
      default:
        triggerFraudAlert(result.sessionId);
        showErrorBlock('Biometric match failed. Session locked.');
        break;
    }
    return;
  }

  // 3. Evaluate step-up rules
  if (result.status == LivenessStatus.mediumRisk) {
    // Prompt for OTP
    showStepUpOtpPage(onSuccess: () => proceedWithTransfer());
  } else {
    // Normal Pass status: complete transfer directly
    proceedWithTransfer();
  }
}
```

---

## 4. Customizing Verification Providers and Modes (API Configured)
The liveness verification provider and challenges adapt dynamically based on backend configurations.

### Active Provider Options
Configure `LIVENESS_PROVIDER` in your backend `.env` settings:
- `aws_rekognition`: Stream real-time camera frames to AWS Rekognition using Cognito Identity pools.
- `google_ml_kit`: Run on-device face and gesture detection with Google ML Kit Face Detection.
- `mock_provider`: Simulated capture for local testing.

### Liveness Modes
The backend `/session` endpoint dictates how the active provider executes gestures (using the `liveness_mode` parameter):
- `PASSIVE`: Direct face photo scan / holding steady.
- `ACTIVE` or `PASSIVE_WITH_ACTIVE_FALLBACK`: Requires face alignment, followed by a randomized set of **two** active liveness challenges (selected from a pool: blink, smile, turn head left, turn head right).

This allows you to configure security levels, providers, and parameters centrally on the backend API without releasing new mobile app versions.

---

## 5. Running the Example App on Android (Step-by-Step)

Follow these steps to build and run the liveness example on an Android Emulator or physical device:

### Step 1: Start the Backend Server
Ensure your backend FastAPI server is running locally (using `uv` or Docker Compose).
By default, the server runs on `http://localhost:8000`.

### Step 2: Configure Android Network Loopback
* **Android Emulator**: The emulator runs on a separate virtual network. To reach the host machine's `localhost`, you **must** use the loopback IP:
  ```
  http://10.0.2.2:8000
  ```
  In the example application UI, toggle off "Offline Mode" and configure the Backend URL text field to `http://10.0.2.2:8000`.
* **Physical Android Device**: Connect both the host machine and the Android device to the same Wi-Fi network. Find the host machine's local IP address (e.g. `192.168.1.50`) and configure the backend URL in the app to:
  ```
  http://192.168.1.50:8000
  ```

### Step 3: Connect Your Device / Launch Emulator
* Verify your device is connected by running:
  ```bash
  flutter devices
  ```
  You should see your active emulator (e.g. `emulator-5554`) or connected device listed.

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
4. Select the target Android device from the terminal prompt or IDE target device selector.

---

## 6. Troubleshooting

### Emulator Camera displays blurred colors or Virtual Scene
By default, the Android Emulator's camera is configured to render a 3D "Virtual Scene" (which looks like a blurred, cartoonish room or moving gradients). Because this virtual feed contains no real human face, the AWS Rekognition `FaceLivenessDetector` will fail to detect a face, causing verification to time out or fail.

To resolve this during testing:
1. **Mock Mode (Recommended for general testing)**:
   In the example app UI testing panel, toggle on **"Simulate Offline Mode (Forced Mock)"**. This bypasses both the real camera and AWS, simulating the liveness verification flow via local mock states without needing a physical face.
2. **Real Webcam Integration (For testing live AWS Rekognition)**:
   If you need to test the real AWS live-streaming flow, map the emulator's front camera to your computer's webcam:
   * Open the **Android Studio Device Manager** (AVD Manager).
   * Click the **Edit (pencil icon)** next to your active virtual device.
   * Click **Show Advanced Settings**.
   * Scroll down to the **Camera** section.
   * Change the **Front** camera from `VirtualScene` to `Webcam0` (or your computer's built-in webcam).
   * Click **Finish** and restart the emulator.
   * Now, the camera stream will show your actual webcam feed, allowing you to position your face in the oval frame to complete the liveness verification.


