import 'dart:async';
import 'package:flutter/material.dart';

import '../models/liveness_config.dart';
import '../models/liveness_result.dart';
import 'liveness_provider.dart';

class MockLivenessProvider implements LivenessProvider {
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
    String? apiKey,
  }) async {
    if (!_initialized || _config == null) {
      return LivenessResult.failure(
        LivenessStatus.fail,
        'SDK has not been initialized. Call initialize() first.',
      );
    }

    final completer = Completer<LivenessResult>();
    
    // Launch a premium mock verification UI overlay (glassmorphism look & feel)
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MockLivenessVerificationScreen(
          onFinished: (result) {
            completer.complete(result);
          },
        );
      },
    );

    return completer.future;
  }
}

class _MockLivenessVerificationScreen extends StatefulWidget {
  final Function(LivenessResult) onFinished;

  const _MockLivenessVerificationScreen({required this.onFinished});

  @override
  State<_MockLivenessVerificationScreen> createState() => _MockLivenessVerificationScreenState();
}

class _MockLivenessVerificationScreenState extends State<_MockLivenessVerificationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;
  String _currentStep = 'Preparing Camera...';
  double _progress = 0.0;
  Timer? _stepTimer;
  int _stepIndex = 0;

  final List<String> _steps = [
    'Position face inside the oval frame',
    'Hold still... validating lighting',
    'Passive Liveness: Looking at camera...',
    'Challenge: Please BLINK now',
    'Analyzing telemetry & anti-spoof checks...',
    'Almost done... generating audit report',
  ];

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startSimulatedPipeline();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startSimulatedPipeline() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (!mounted) return;
      
      setState(() {
        _stepIndex++;
        _progress = _stepIndex / _steps.length;
        if (_stepIndex < _steps.length) {
          _currentStep = _steps[_stepIndex];
        } else {
          _stepTimer?.cancel();
          _finalizeMockVerification();
        }
      });
    });
  }

  void _finalizeMockVerification() {
    // Generate pass result
    final result = LivenessResult(
      success: true,
      status: LivenessStatus.pass,
      confidence: 99.4,
      sessionId: 'mock_session_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      provider: 'mock_provider',
      imageReference: 'mock://reference_images/face_audit_mock.jpg',
    );
    
    Navigator.of(context).pop();
    widget.onFinished(result);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent physical back button cancellation
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              // Header UI
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FACEGUARD LIVENESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            _stepTimer?.cancel();
                            Navigator.of(context).pop();
                            widget.onFinished(
                              LivenessResult.failure(
                                LivenessStatus.cancelled,
                                'Verification cancelled by user',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),

              // Central Oval Face Frame + Scanner Animation
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Oval Frame
                        Container(
                          width: size.width * 0.7,
                          height: size.height * 0.4,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF00C853).withOpacity(0.8),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(size.width * 0.35, size.height * 0.2),
                            ),
                          ),
                        ),
                        
                        // Scanner Line
                        AnimatedBuilder(
                          animation: _scannerController,
                          builder: (context, child) {
                            final double translation = (_scannerController.value * (size.height * 0.38)) - (size.height * 0.19);
                            return Transform.translate(
                              offset: Offset(0, translation),
                              child: Container(
                                width: size.width * 0.65,
                                height: 2,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00C853).withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  color: const Color(0xFF00C853),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Dummy Face Outline
                        Icon(
                          Icons.face,
                          size: 140,
                          color: Colors.white24.withOpacity(0.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    
                    // Guided Message Instruction
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _currentStep,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom status tag
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Text(
                          'MOCK LIVENESS RUNNING',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
