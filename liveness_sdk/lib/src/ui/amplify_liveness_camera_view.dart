import 'package:face_liveness_detector/face_liveness_detector.dart';
import 'package:flutter/material.dart';

class AmplifyLivenessCameraView extends StatelessWidget {
  final String sessionId;
  final String region;

  const AmplifyLivenessCameraView({
    Key? key,
    required this.sessionId,
    required this.region,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: const Text(
            'AWS Liveness Detection',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: FaceLivenessDetector(
            sessionId: sessionId,
            region: region,
            onComplete: () async {
              debugPrint('AmplifyLivenessCameraView: Video upload and check complete.');
              Navigator.of(context).pop(true);
            },
            onError: (err) {
              debugPrint('AmplifyLivenessCameraView: Liveness error occurred: $err');
              _showErrorDialog(context, err.toString());
            },
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Streaming Error', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'AWS Liveness stream failed: $message\n\nPlease ensure your Cognito settings are configured correctly.',
          style: const TextStyle(color: Colors.white70),
        ),
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
}
