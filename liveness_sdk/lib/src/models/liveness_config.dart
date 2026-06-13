enum LivenessEnvironment {
  development,
  staging,
  production,
}

class LivenessConfig {
  /// The base URL of the FastAPI liveness backend (e.g. "http://10.0.2.2:8000" for Android emulator)
  final String backendUrl;

  /// Optional API Key for authenticating against the backend
  final String apiKey;

  /// Target environment: development, staging, or production
  final LivenessEnvironment environment;

  /// Maximum number of verification retries allowed before returning a failure
  final int maxRetries;

  /// Whether active challenge fallback (blink, smile, turn head) is enabled
  final bool activeFallbackEnabled;

  /// Session recording/capture timeout in seconds
  final int timeoutSeconds;

  /// Threshold for a passing score (usually 95.0%)
  final double passThreshold;

  /// Trigger mock mode directly in the Flutter client for local simulator testing
  final bool forceMockMode;

  const LivenessConfig({
    required this.backendUrl,
    this.apiKey = '',
    this.environment = LivenessEnvironment.development,
    this.maxRetries = 3,
    this.activeFallbackEnabled = true,
    this.timeoutSeconds = 15,
    this.passThreshold = 95.0,
    this.forceMockMode = false,
  });

  LivenessConfig copyWith({
    String? backendUrl,
    String? apiKey,
    LivenessEnvironment? environment,
    int? maxRetries,
    bool? activeFallbackEnabled,
    int? timeoutSeconds,
    double? passThreshold,
    bool? forceMockMode,
  }) {
    return LivenessConfig(
      backendUrl: backendUrl ?? this.backendUrl,
      apiKey: apiKey ?? this.apiKey,
      environment: environment ?? this.environment,
      maxRetries: maxRetries ?? this.maxRetries,
      activeFallbackEnabled: activeFallbackEnabled ?? this.activeFallbackEnabled,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      passThreshold: passThreshold ?? this.passThreshold,
      forceMockMode: forceMockMode ?? this.forceMockMode,
    );
  }
}
