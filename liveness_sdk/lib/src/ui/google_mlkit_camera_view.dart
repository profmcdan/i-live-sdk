import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge {
  blink,
  smile,
  turnLeft,
  turnRight,
  turnUp,
  turnDown,
  tiltSideways,
}

class GoogleMlKitCameraView extends StatefulWidget {
  final String sessionId;
  final int timeoutSeconds;
  final String livenessMode;

  const GoogleMlKitCameraView({
    Key? key,
    required this.sessionId,
    required this.timeoutSeconds,
    required this.livenessMode,
  }) : super(key: key);

  @override
  State<GoogleMlKitCameraView> createState() => _GoogleMlKitCameraViewState();
}

class _GoogleMlKitCameraViewState extends State<GoogleMlKitCameraView> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  String _guideMessage = 'Initializing camera...';
  Color _frameColor = Colors.white30;

  late FaceDetector _faceDetector;
  late AnimationController _scannerController;
  Timer? _timeoutTimer;
  int _secondsRemaining = 0;

  // Liveness pipeline states
  final List<LivenessChallenge> _challenges = [];
  int _currentChallengeIndex = -1; // -1: Alignment stage, 0: First challenge, 1: Second challenge
  
  // Alignment tracking variables
  int _consecutiveSteadyFrames = 0;
  static const int _requiredSteadyFrames = 6; // roughly 0.5-0.8s depending on frame rate

  // Gesture state tracking
  bool _blinkClosedReached = false;
  bool _alignmentPassed = false;
  bool _challenge1Passed = false;
  bool _challenge2Passed = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeoutSeconds;

    // Pick 2 random challenges from the pool of 4
    final pool = List<LivenessChallenge>.from(LivenessChallenge.values)..shuffle();
    _challenges.addAll(pool.take(2));
    debugPrint('GoogleMlKitLiveness: Selected challenges: $_challenges');

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _scannerController.dispose();
    _faceDetector.close();
    if (_cameraController != null) {
      if (_cameraController!.value.isRecordingVideo) {
        _cameraController!.stopVideoRecording().catchError((e) => debugPrint(e.toString()));
      }
      _cameraController!.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras found on device');
        return;
      }

      // Find front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _guideMessage = 'Align your face in the oval frame';
        _frameColor = Colors.blueAccent;
      });

      _startTimeoutTimer();

      // Start processing frames from camera stream (sequential mode only)
      await _cameraController!.startImageStream((CameraImage image) {
        _processCameraImage(image, frontCamera);
      });
    } catch (e) {
      debugPrint('GoogleMlKitLiveness: Camera Init Error: $e');
      _showError('Camera permission denied or camera error');
    }
  }

  void _startTimeoutTimer() {
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
  }

  Future<void> _processCameraImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        _isProcessingFrame = false;
        return;
      }

      _evaluateLivenessState(faces);
    } catch (e) {
      debugPrint('GoogleMlKitLiveness: Frame process error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _evaluateLivenessState(List<Face> faces) {
    if (faces.isEmpty) {
      _consecutiveSteadyFrames = 0;
      setState(() {
        _guideMessage = 'No face detected. Align in frame.';
        _frameColor = Colors.redAccent;
      });
      return;
    }

    if (faces.length > 1) {
      _consecutiveSteadyFrames = 0;
      setState(() {
        _guideMessage = 'Multiple faces detected. Keep only one face.';
        _frameColor = Colors.redAccent;
      });
      return;
    }

    final Face face = faces.first;

    // Stage 0: Face Alignment
    if (_currentChallengeIndex == -1) {
      _consecutiveSteadyFrames++;
      if (_consecutiveSteadyFrames >= _requiredSteadyFrames) {
        setState(() {
          _alignmentPassed = true;
          _currentChallengeIndex = 0;
          _frameColor = Colors.orangeAccent;
          _guideMessage = _getChallengeInstruction(_challenges[0]);
        });
      } else {
        setState(() {
          _guideMessage = 'Hold steady...';
          _frameColor = Colors.blueAccent;
        });
      }
      return;
    }

    // Stage 1: First Challenge
    if (_currentChallengeIndex == 0) {
      final challenge = _challenges[0];
      final passed = _checkChallengeGesture(face, challenge);
      if (passed) {
        setState(() {
          _challenge1Passed = true;
          _currentChallengeIndex = 1;
          _frameColor = Colors.orangeAccent;
          _guideMessage = _getChallengeInstruction(_challenges[1]);
          // Reset temp states
          _blinkClosedReached = false;
        });
      }
      return;
    }

    // Stage 2: Second Challenge
    if (_currentChallengeIndex == 1) {
      final challenge = _challenges[1];
      final passed = _checkChallengeGesture(face, challenge);
      if (passed) {
        setState(() {
          _challenge2Passed = true;
          _currentChallengeIndex = 2; // pipeline finished
          _frameColor = const Color(0xFF00E676); // Green success
          _guideMessage = 'Liveness passed! Wrapping up...';
        });

        _onPipelineSuccess();
      }
      return;
    }
  }

  bool _checkChallengeGesture(Face face, LivenessChallenge challenge) {
    switch (challenge) {
      case LivenessChallenge.blink:
        final leftProb = face.leftEyeOpenProbability ?? 1.0;
        final rightProb = face.rightEyeOpenProbability ?? 1.0;

        // Step 1: Detect eyes closed
        if (leftProb < 0.25 && rightProb < 0.25) {
          _blinkClosedReached = true;
        }

        // Step 2: Detect eyes open again
        if (_blinkClosedReached && leftProb > 0.65 && rightProb > 0.65) {
          return true;
        }
        break;

      case LivenessChallenge.smile:
        final smileProb = face.smilingProbability ?? 0.0;
        if (smileProb > 0.75) {
          return true;
        }
        break;

      case LivenessChallenge.turnLeft:
        final yaw = face.headEulerAngleY ?? 0.0;
        // Depending on sensor mirroring, turn left is represented by positive yaw
        if (yaw > 18.0) {
          return true;
        }
        break;

      case LivenessChallenge.turnRight:
        final yaw = face.headEulerAngleY ?? 0.0;
        // Depending on sensor mirroring, turn right is represented by negative yaw
        if (yaw < -18.0) {
          return true;
        }
        break;

      case LivenessChallenge.turnUp:
        final pitch = face.headEulerAngleX ?? 0.0;
        if (pitch > 12.0) {
          return true;
        }
        break;

      case LivenessChallenge.turnDown:
        final pitch = face.headEulerAngleX ?? 0.0;
        if (pitch < -12.0) {
          return true;
        }
        break;

      case LivenessChallenge.tiltSideways:
        final roll = face.headEulerAngleZ ?? 0.0;
        if (roll.abs() > 15.0) {
          return true;
        }
        break;
    }
    return false;
  }

  String _getChallengeInstruction(LivenessChallenge challenge) {
    switch (challenge) {
      case LivenessChallenge.blink:
        return 'Please BLINK clearly';
      case LivenessChallenge.smile:
        return 'Please SMILE warmly';
      case LivenessChallenge.turnLeft:
        return 'Please TURN HEAD LEFT';
      case LivenessChallenge.turnRight:
        return 'Please TURN HEAD RIGHT';
      case LivenessChallenge.turnUp:
        return 'Please TILT HEAD UP';
      case LivenessChallenge.turnDown:
        return 'Please TILT HEAD DOWN';
      case LivenessChallenge.tiltSideways:
        return 'Please TILT HEAD SIDEWAYS';
    }
    return 'Perform the challenge';
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation imageRotation = _rotationFromSensor(camera.sensorOrientation);
      final InputImageFormat imageFormat = _formatFromRaw(image.format.raw);

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: imageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('GoogleMlKitLiveness: Error converting camera frame: $e');
      return null;
    }
  }

  InputImageRotation _rotationFromSensor(int orientation) {
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _formatFromRaw(int rawValue) {
    if (Platform.isAndroid) {
      return InputImageFormat.nv21;
    } else {
      return InputImageFormat.bgra8888;
    }
  }

  Future<void> _onPipelineSuccess() async {
    _timeoutTimer?.cancel();
    
    // Stop image stream so we can record video
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    setState(() {
      _guideMessage = 'Securing session... Hold still';
      _frameColor = const Color(0xFF00E676);
    });

    try {
      // Start video recording sequentially
      await _cameraController!.startVideoRecording();
      // Record for 5.0 seconds to capture a longer sequential clip
      await Future.delayed(const Duration(milliseconds: 5000));
      final file = await _cameraController!.stopVideoRecording();
      if (mounted) {
        Navigator.of(context).pop(file.path);
      }
    } catch (e) {
      debugPrint('GoogleMlKitLiveness: Error recording verification video: $e');
      if (mounted) {
        Navigator.of(context).pop(null);
      }
    }
  }

  void _onTimeout() {
    _showError('Verification timed out. Please try again.');
  }

  void _showError(String message) {
    if (!mounted) return;
    
    // Stop image stream and recording on failure
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream().catchError((e) => debugPrint(e.toString()));
      }
      if (_cameraController!.value.isRecordingVideo) {
        _cameraController!.stopVideoRecording().catchError((e) => debugPrint(e.toString()));
      }
    }

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
                    if (_currentChallengeIndex < 2)
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
                    'ML Kit Liveness',
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

            // Bottom UI: Checklist & dynamic guide message
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checklist Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChecklistItem(
                          '1. Center face in frame',
                          _alignmentPassed,
                          _currentChallengeIndex == -1,
                        ),
                        const SizedBox(height: 10),
                        if (_challenges.isNotEmpty) ...[
                          _buildChecklistItem(
                            '2. ${_getChallengeDescription(_challenges[0])}',
                            _challenge1Passed,
                            _currentChallengeIndex == 0,
                          ),
                          const SizedBox(height: 10),
                          _buildChecklistItem(
                            '3. ${_getChallengeDescription(_challenges[1])}',
                            _challenge2Passed,
                            _currentChallengeIndex == 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Dynamic Instructions Display Bubble
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: _frameColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _frameColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentChallengeIndex >= 0 && _currentChallengeIndex < 2)
                          const Padding(
                            padding: EdgeInsets.only(right: 12.0),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        Text(
                          _guideMessage.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _currentChallengeIndex == 2 ? const Color(0xFF00E676) : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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

  Widget _buildChecklistItem(String label, bool completed, bool active) {
    Color itemColor = Colors.white38;
    Widget icon = const Icon(Icons.circle_outlined, color: Colors.white24, size: 20);

    if (completed) {
      itemColor = const Color(0xFF00E676);
      icon = const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20);
    } else if (active) {
      itemColor = Colors.amberAccent;
      icon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.amberAccent,
        ),
      );
    }

    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: itemColor,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _getChallengeDescription(LivenessChallenge challenge) {
    switch (challenge) {
      case LivenessChallenge.blink:
        return 'Blink clearly';
      case LivenessChallenge.smile:
        return 'Smile warmly';
      case LivenessChallenge.turnLeft:
        return 'Turn head left';
      case LivenessChallenge.turnRight:
        return 'Turn head right';
      case LivenessChallenge.turnUp:
        return 'Tilt head up';
      case LivenessChallenge.turnDown:
        return 'Tilt head down';
      case LivenessChallenge.tiltSideways:
        return 'Tilt head sideways';
    }
  }
}
