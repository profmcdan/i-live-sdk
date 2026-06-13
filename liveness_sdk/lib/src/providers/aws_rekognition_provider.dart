import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/liveness_config.dart';
import '../models/liveness_result.dart';
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
  Future<LivenessResult> verify(BuildContext context) async {
    if (!_initialized || _config == null) {
      return LivenessResult.failure(
        LivenessStatus.fail,
        'SDK has not been initialized. Call initialize() first.',
      );
    }

    final config = _config!;

    try {
      // 1. Create session from custom FastAPI Backend (FR-002, Section 7/9)
      final sessionUrl = Uri.parse('${config.backendUrl}/api/v1/liveness/session');
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
      debugPrint('LivenessSDK: Session created successfully. ID: $sessionId, Mode: $serverMode');

      // 2. Open Liveness Camera View for guided capture (FR-004, FR-005, FR-006)
      if (!context.mounted) {
        return LivenessResult.failure(LivenessStatus.fail, 'Context is no longer valid');
      }

      final bool? captureSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => LivenessCameraView(
            sessionId: sessionId,
            timeoutSeconds: config.timeoutSeconds,
            livenessMode: serverMode,
          ),
        ),
      );

      if (captureSuccess == null || !captureSuccess) {
        return LivenessResult.failure(
          LivenessStatus.cancelled,
          'Liveness verification cancelled by user',
          sessionId: sessionId,
        );
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
