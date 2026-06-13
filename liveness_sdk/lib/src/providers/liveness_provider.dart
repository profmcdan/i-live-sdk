import 'package:flutter/widgets.dart';
import '../models/liveness_config.dart';
import '../models/liveness_result.dart';

abstract class LivenessProvider {
  /// Initialize the provider with specific configurations
  Future<void> initialize(LivenessConfig config);

  /// Performs the verification flow.
  /// Launches UI controls if necessary and coordinates backend validation.
  Future<LivenessResult> verify(BuildContext context);
  
  /// Helper to check if the current provider is ready to perform validation
  bool get isInitialized;
}
