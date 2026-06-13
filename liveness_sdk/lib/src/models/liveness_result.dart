enum LivenessStatus {
  pass,
  fail,
  timeout,
  cameraDenied,
  networkError,
  lowConfidence,
  mediumRisk,
  cancelled,
}

class LivenessResult {
  final bool success;
  final LivenessStatus status;
  final double confidence;
  final String sessionId;
  final String provider;
  final String imageReference;
  final String? errorMessage;
  final DateTime timestamp;

  LivenessResult({
    required this.success,
    required this.status,
    required this.confidence,
    required this.sessionId,
    required this.provider,
    required this.imageReference,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LivenessResult.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toUpperCase() ?? 'FAIL';
    final isSuccess = statusStr == 'PASS' || statusStr == 'MEDIUM_RISK';
    
    LivenessStatus mappedStatus;
    switch (statusStr) {
      case 'PASS':
        mappedStatus = LivenessStatus.pass;
        break;
      case 'MEDIUM_RISK':
        mappedStatus = LivenessStatus.mediumRisk;
        break;
      case 'LOW_CONFIDENCE':
        mappedStatus = LivenessStatus.lowConfidence;
        break;
      case 'TIMEOUT':
        mappedStatus = LivenessStatus.timeout;
        break;
      case 'CAMERA_DENIED':
        mappedStatus = LivenessStatus.cameraDenied;
        break;
      case 'NETWORK_ERROR':
        mappedStatus = LivenessStatus.networkError;
        break;
      case 'CANCELLED':
        mappedStatus = LivenessStatus.cancelled;
        break;
      case 'FAIL':
      default:
        mappedStatus = LivenessStatus.fail;
        break;
    }

    return LivenessResult(
      success: isSuccess,
      status: mappedStatus,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      sessionId: json['provider_session_id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'unknown',
      imageReference: json['image_reference']?.toString() ?? '',
      errorMessage: json['error_message']?.toString(),
    );
  }

  factory LivenessResult.failure(LivenessStatus status, String errorMessage, {String sessionId = ''}) {
    return LivenessResult(
      success: false,
      status: status,
      confidence: 0.0,
      sessionId: sessionId,
      provider: 'none',
      imageReference: '',
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'status': status.name.toUpperCase(),
      'confidence': confidence,
      'session_id': sessionId,
      'provider': provider,
      'image_reference': imageReference,
      'error_message': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'LivenessResult(success: $success, status: $status, confidence: $confidence%, sessionId: $sessionId)';
  }
}
