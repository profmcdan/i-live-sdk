import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LivenessCameraView extends StatefulWidget {
  final String sessionId;
  final int timeoutSeconds;
  final String livenessMode; // "PASSIVE", "ACTIVE", "PASSIVE_WITH_ACTIVE_FALLBACK"

  const LivenessCameraView({
    Key? key,
    required this.sessionId,
    required this.timeoutSeconds,
    required this.livenessMode,
  }) : super(key: key);

  @override
  State<LivenessCameraView> createState() => _LivenessCameraViewState();
}

class _LivenessCameraViewState extends State<LivenessCameraView> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String _guideMessage = 'Initializing camera...';
  Color _frameColor = Colors.white30;
  
  late AnimationController _scannerController;
  Timer? _timeoutTimer;
  Timer? _challengeTimer;
  int _secondsRemaining = 0;
  
  // Liveness check stages
  int _currentStage = 0; // 0: Align, 1: Steady check, 2: Challenge (blink/smile)
  String _challengeInstruction = '';
  XFile? _recordedVideo;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeoutSeconds;
    
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _initializeCamera();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _challengeTimer?.cancel();
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras found on device');
        return;
      }

      // Select front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false, // Audio not needed for Rekognition Face Liveness
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _guideMessage = 'Align your face in the oval frame';
        _frameColor = Colors.blueAccent;
      });

      _startLivenessPipeline();
    } catch (e) {
      debugPrint('LivenessSDK: Camera Init Error: $e');
      _showError('Camera permission denied or camera error');
    }
  }

  void _startLivenessPipeline() {
    // 1. Start session timeout countdown
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timeoutTimer?.cancel();
          _onTimeout();
        }
      });
    });

    // 2. Simulate Face Alignment delay (e.g. 2.5 seconds user aligns face)
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _startVerificationRecording();
    });
  }

  Future<void> _startVerificationRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      final mode = widget.livenessMode.toUpperCase();
      
      setState(() {
        if (mode == 'ACTIVE') {
          _currentStage = 2;
          _challengeInstruction = 'Please BLINK clearly';
          _guideMessage = 'Blink clearly';
        } else {
          _currentStage = 1;
          _guideMessage = 'Keep steady. Capturing...';
        }
        _frameColor = const Color(0xFF00E676); // Vibrant Green
        _isRecording = true;
      });

      await _cameraController!.startVideoRecording();
      
      // If passive with active fallback is requested, trigger challenge mid-session
      if (mode == 'PASSIVE_WITH_ACTIVE_FALLBACK') {
        _challengeTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _currentStage = 2;
            _challengeInstruction = 'Please BLINK clearly';
            _guideMessage = 'Blink clearly';
          });
        });
      }

      // Record for 4.5 seconds to capture high-quality frame sequences
      Timer(const Duration(milliseconds: 4500), () {
        _stopVerificationRecording();
      });

    } catch (e) {
      debugPrint('LivenessSDK: Recording start error: $e');
      _showError('Failed to capture liveness video');
    }
  }

  Future<void> _stopVerificationRecording() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _guideMessage = 'Analyzing frames...';
        _frameColor = Colors.amberAccent;
      });

      _recordedVideo = videoFile;
      
      // Complete and exit returning the recorded video file path
      Navigator.of(context).pop(videoFile.path);
    } catch (e) {
      debugPrint('LivenessSDK: Recording stop error: $e');
      _showError('Analysis failed during video capture');
    }
  }

  void _onTimeout() {
    _showError('Verification timed out. Please try again.');
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Verification Failed', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss dialog
              Navigator.of(context).pop(false); // Dismiss camera screen
            },
            child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview
            if (_isCameraInitialized && _cameraController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: 1 / _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00E676),
                ),
              ),

            // Translucent black overlay covering non-oval area
            if (_isCameraInitialized)
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Center(
                      child: Container(
                        width: size.width * 0.75,
                        height: size.height * 0.42,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(size.width * 0.375, size.height * 0.21),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Animated scan line & oval boundary border representation
            if (_isCameraInitialized)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size.width * 0.75,
                      height: size.height * 0.42,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _frameColor,
                          width: 3.5,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(size.width * 0.375, size.height * 0.21),
                        ),
                      ),
                    ),
                    
                    // Scanning animation line
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _scannerController,
                        builder: (context, child) {
                          final double translation = (_scannerController.value * (size.height * 0.4)) - (size.height * 0.2);
                          return Transform.translate(
                            offset: Offset(0, translation),
                            child: Container(
                              width: size.width * 0.7,
                              height: 3,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: _frameColor.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                                color: _frameColor,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

            // Top Header: Title and Countdown timer
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  const Text(
                    'Liveness Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_secondsRemaining}s',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom UI: Dynamic capture status message & challenges
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Challenge prompt bubble (e.g. blink challenge)
                  if (_currentStage == 2 && _challengeInstruction.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.face, color: Colors.black87),
                            const SizedBox(width: 8),
                            Text(
                              _challengeInstruction,
                              style: const TextStyle(
                                color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRecording)
                          const Padding(
                            padding: EdgeInsets.only(right: 12.0),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF00E676),
                              ),
                            ),
                          ),
                        Text(
                          _guideMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
