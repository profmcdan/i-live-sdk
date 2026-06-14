library liveness_sdk;

import 'package:flutter/widgets.dart';

import 'src/models/liveness_config.dart';
import 'src/models/liveness_result.dart';
import 'src/providers/aws_rekognition_provider.dart';
import 'src/providers/liveness_provider.dart';
import 'src/providers/mock_liveness_provider.dart';

export 'src/models/liveness_config.dart';
export 'src/models/liveness_result.dart';
export 'src/providers/liveness_provider.dart';

class LivenessSDK {
  static LivenessSDK? _instance;
  
  final LivenessConfig config;
  final LivenessProvider provider;

  LivenessSDK._(this.config, this.provider);

  /// Initializes the SDK with a target configuration and chooses the active provider.
  static Future<void> initialize({
    required String backendUrl,
    String apiKey = '',
    LivenessEnvironment environment = LivenessEnvironment.development,
    int maxRetries = 3,
    bool activeFallbackEnabled = true,
    int timeoutSeconds = 15,
    double passThreshold = 95.0,
    bool forceMockMode = false,
  }) async {
    final config = LivenessConfig(
      backendUrl: backendUrl,
      apiKey: apiKey,
      environment: environment,
      maxRetries: maxRetries,
      activeFallbackEnabled: activeFallbackEnabled,
      timeoutSeconds: timeoutSeconds,
      passThreshold: passThreshold,
      forceMockMode: forceMockMode,
    );

    // Determine appropriate provider implementation
    LivenessProvider provider;
    if (forceMockMode) {
      provider = MockLivenessProvider();
    } else {
      provider = AwsRekognitionLivenessProvider();
    }

    await provider.initialize(config);
    _instance = LivenessSDK._(config, provider);
  }

  /// Launch the verification capture experience.
  /// Pre-requisite: Must have initialized the SDK using [initialize].
  static Future<LivenessResult> verify(
    BuildContext context, {
    String? userId,
    String? bvn,
    String? verificationType,
    String? channel,
  }) async {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'LivenessSDK has not been initialized. Please call LivenessSDK.initialize(...) first.',
      );
    }
    
    return await instance.provider.verify(
      context,
      userId: userId,
      bvn: bvn,
      verificationType: verificationType,
      channel: channel,
    );
  }
}
