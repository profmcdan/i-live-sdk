import 'dart:convert';
import 'dart:io';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/liveness_config.dart';
import '../models/liveness_result.dart';
import '../ui/amplify_liveness_camera_view.dart';
import '../ui/google_mlkit_camera_view.dart';
import '../ui/liveness_camera_view.dart';
import 'liveness_provider.dart';

class AwsRekognitionLivenessProvider implements LivenessProvider {
  LivenessConfig? _config;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(LivenessConfig config) async {
    _config = config;
    _initialized = true;
  }

  @override
  Future<LivenessResult> verify(
    BuildContext context, {
    String? userId,
    String? bvn,
    String? verificationType,
    String? channel,
  }) async {
    if (!_initialized || _config == null) {
      return LivenessResult.failure(
        LivenessStatus.fail,
        'SDK has not been initialized. Call initialize() first.',
      );
    }

    final config = _config!;

    try {
      // 1. Create session from custom FastAPI Backend (FR-002, Section 7/9)
      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) queryParams['user_id'] = userId;
      if (bvn != null && bvn.isNotEmpty) queryParams['bvn'] = bvn;
      if (verificationType != null && verificationType.isNotEmpty) {
        queryParams['verification_type'] = verificationType;
      }
      if (channel != null && channel.isNotEmpty) {
        queryParams['channel'] = channel;
      }

      final sessionUrl = Uri.parse('${config.backendUrl}/api/v1/liveness/session').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final headers = {
        'Content-Type': 'application/json',
        if (config.apiKey.isNotEmpty) 'X-API-Key': config.apiKey,
      };

      debugPrint('LivenessSDK: Requesting session creation from $sessionUrl');
      final sessionResponse = await http.post(sessionUrl, headers: headers).timeout(
        const Duration(seconds: 10),
      );

      if (sessionResponse.statusCode != 201) {
        return LivenessResult.failure(
          LivenessStatus.networkError,
          'Failed to create liveness session. Server returned ${sessionResponse.statusCode}',
        );
      }

      final sessionData = jsonDecode(sessionResponse.body);
      final sessionId = sessionData['session_id'] as String;
      final serverMode = sessionData['liveness_mode']?.toString() ?? 'PASSIVE_WITH_ACTIVE_FALLBACK';
      final cognitoPoolId = sessionData['cognito_pool_id'] as String?;
      final cognitoRegion = sessionData['cognito_region'] as String? ?? 'us-east-1';
      final provider = sessionData['provider'] as String? ?? 'aws_rekognition';

      debugPrint('LivenessSDK: Session created successfully. ID: $sessionId, Mode: $serverMode, Provider: $provider');

      if (!context.mounted) {
        return LivenessResult.failure(LivenessStatus.fail, 'Context is no longer valid');
      }

      bool? captureSuccess;
      String? videoPath;

      // 2. Open Liveness Camera View for guided capture based on provider
      if (provider == 'google_ml_kit') {
        debugPrint('LivenessSDK: Routing to Google ML Kit Liveness Camera View.');
        final dynamic pushResult = await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (context) => GoogleMlKitCameraView(
              sessionId: sessionId,
              timeoutSeconds: config.timeoutSeconds,
              livenessMode: serverMode,
            ),
          ),
        );
        if (pushResult is String) {
          videoPath = pushResult;
          captureSuccess = true;
        } else {
          captureSuccess = false;
        }
      } else if (cognitoPoolId != null && cognitoPoolId.isNotEmpty) {
        // Option A: Stream live frames directly to AWS via Amplify FaceLivenessDetector
        debugPrint('LivenessSDK: Dynamically configuring Amplify Auth with pool: $cognitoPoolId');
        await _configureAmplify(cognitoPoolId, cognitoRegion);

        if (!context.mounted) return LivenessResult.failure(LivenessStatus.fail, 'Context is no longer valid');

        final dynamic awsSuccess = await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (context) => AmplifyLivenessCameraView(
              sessionId: sessionId,
              region: cognitoRegion,
            ),
          ),
        );
        captureSuccess = awsSuccess == true;
      } else {
        // Fallback: Custom local camera recording (Useful for Mock/Offline environments)
        debugPrint('LivenessSDK: Cognito not configured. Using custom local camera view fallback.');
        final dynamic pushResult = await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (context) => LivenessCameraView(
              sessionId: sessionId,
              timeoutSeconds: config.timeoutSeconds,
              livenessMode: serverMode,
            ),
          ),
        );
        if (pushResult is String) {
          videoPath = pushResult;
          captureSuccess = true;
        } else {
          captureSuccess = false;
        }
      }

      if (captureSuccess == null || !captureSuccess) {
        if (videoPath != null) _deleteLocalFile(videoPath);
        return LivenessResult.failure(
          LivenessStatus.cancelled,
          'Liveness verification cancelled or failed',
          sessionId: sessionId,
        );
      }

      // If we have a custom recorded video file, upload it strictly to S3 via backend
      if (videoPath != null) {
        final uploadOk = await _uploadSessionVideo(sessionId, videoPath, config.backendUrl, config.apiKey);
        if (!uploadOk) {
          _deleteLocalFile(videoPath);
          return LivenessResult.failure(
            LivenessStatus.fail,
            'Failed to upload liveness verification video to S3 storage.',
            sessionId: sessionId,
          );
        }
        _deleteLocalFile(videoPath); // Secure clean up after upload success
      }

      // 3. Assemble Device Intelligence details (Section 11)
      final deviceTelemetry = await _gatherDeviceTelemetry();

      // 4. Verify session on Backend (FR-007, Section 9)
      final verifyUrl = Uri.parse('${config.backendUrl}/api/v1/liveness/verify');
      final verifyPayload = {
        'session_id': sessionId,
        'device_intelligence': deviceTelemetry,
      };

      debugPrint('LivenessSDK: Verifying session $sessionId on backend');
      final verifyResponse = await http.post(
        verifyUrl,
        headers: headers,
        body: jsonEncode(verifyPayload),
      ).timeout(const Duration(seconds: 15));

      if (verifyResponse.statusCode != 200) {
        return LivenessResult.failure(
          LivenessStatus.networkError,
          'Failed to verify liveness session. Server returned ${verifyResponse.statusCode}',
          sessionId: sessionId,
        );
      }

      final verifyData = jsonDecode(verifyResponse.body);
      final result = LivenessResult.fromJson(verifyData);
      debugPrint('LivenessSDK: Session verified. Result: $result');
      
      return result;

    } catch (e) {
      debugPrint('LivenessSDK: Error occurred during verification flow: $e');
      return LivenessResult.failure(
        LivenessStatus.networkError,
        'Network or communication error: ${e.toString()}',
      );
    }
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('LivenessSDK: Securely cleaned up temporary captured verification video.');
      }
    } catch (e) {
      debugPrint('LivenessSDK: Error deleting local file: $e');
    }
  }

  Future<bool> _uploadSessionVideo(String sessionId, String videoPath, String backendUrl, String apiKey) async {
    try {
      final uploadUrl = Uri.parse('$backendUrl/api/v1/liveness/session/$sessionId/video/upload');
      debugPrint('LivenessSDK: Uploading verification video to S3 via: $uploadUrl');

      final request = http.MultipartRequest('POST', uploadUrl);
      if (apiKey.isNotEmpty) {
        request.headers['X-API-Key'] = apiKey;
      }
      request.files.add(
        await http.MultipartFile.fromPath('file', videoPath),
      );

      final response = await request.send().timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LivenessSDK: Error uploading verification video: $e');
      return false;
    }
  }

  Future<void> _configureAmplify(String poolId, String region) async {
    if (Amplify.isConfigured) return;

    try {
      final authPlugin = AmplifyAuthCognito();
      await Amplify.addPlugin(authPlugin);

      // Create inline Amplify Cognito Configuration JSON dynamically
      final configString = '''{
        "UserAgent": "aws-amplify-cli/2.0",
        "Version": "1.0",
        "auth": {
          "plugins": {
            "awsCognitoAuthPlugin": {
              "CredentialsProvider": {
                "CognitoIdentity": {
                  "Default": {
                    "PoolId": "$poolId",
                    "Region": "$region"
                  }
                }
              }
            }
          }
        }
      }''';

      await Amplify.configure(configString);
    } catch (e) {
      debugPrint('LivenessSDK: Amplify Configuration Error: $e');
    }
  }

  Future<Map<String, String>> _gatherDeviceTelemetry() async {
    String deviceOs = 'Unknown OS';
    String deviceModel = 'Simulator/Device';
    
    try {
      if (Platform.isAndroid) {
        deviceOs = 'Android ${Platform.operatingSystemVersion}';
        deviceModel = 'Android Device';
      } else if (Platform.isIOS) {
        deviceOs = 'iOS ${Platform.operatingSystemVersion}';
        deviceModel = 'iOS Device';
      }
    } catch (_) {
      // Fallback if Platform is not available (e.g. running in web environment)
    }

    return {
      'device_id': 'dev_id_${DateTime.now().millisecondsSinceEpoch}',
      'device_model': deviceModel,
      'device_os': deviceOs,
      'ip_address': '192.168.1.1', // Standard fallback, backend will check header
      'latitude': '6.5244',       // Standard coordinates for Lagos (CST HQ)
      'longitude': '3.3792',
    };
  }
}
