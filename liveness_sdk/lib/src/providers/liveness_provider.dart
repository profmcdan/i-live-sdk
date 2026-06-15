import 'package:flutter/widgets.dart';
import '../models/liveness_config.dart';
import '../models/liveness_result.dart';

abstract class LivenessProvider {
  /// Initialize the provider with specific configurations
  Future<void> initialize(LivenessConfig config);

  Future<LivenessResult> verify(
    BuildContext context, {
    String? userId,
    String? bvn,
    String? verificationType,
    String? channel,
    String? apiKey,
  });
  
  /// Helper to check if the current provider is ready to perform validation
  bool get isInitialized;
}
