import 'package:flutter/material.dart';
import 'package:kolomoni_liveness_sdk/kolomoni_liveness_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kolomoni Biometric Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF0D47A1), // Sleek Banking Navy Blue
        scaffoldBackgroundColor: const Color(0xFF0F121A), // Sleek obsidian/slate background
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2979FF),
          secondary: Color(0xFF00E676), // Verify Success Green
          surface: Color(0xFF171B26),
        ),
      ),
      home: const DemoHomeScreen(),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({Key? key}) : super(key: key);

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  bool _forceMock = true;
  String _backendUrl = 'http://localhost:8000';
  LivenessResult? _lastResult;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  Future<void> _initializeSDK() async {
    try {
      await LivenessSDK.initialize(
        backendUrl: _backendUrl,
        environment: LivenessEnvironment.development,
        forceMockMode: _forceMock,
        activeFallbackEnabled: true,
      );
      debugPrint('DemoApp: Liveness SDK Initialized successfully.');
    } catch (e) {
      debugPrint('DemoApp: SDK Init Error: $e');
    }
  }

  Future<void> _triggerVerification(String actionName) async {
    setState(() {
      _isProcessing = true;
    });

    // Re-initialize config to capture toggles
    await _initializeSDK();

    if (!mounted) return;

    // Show a loading/action initialization hud briefly
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting liveness audit for: $actionName'),
        duration: const Duration(milliseconds: 1000),
      ),
    );

    try {
      final result = await LivenessSDK.verify(context);
      
      setState(() {
        _lastResult = result;
        _isProcessing = false;
      });

      // Show action popup depending on the decision engine outcome
      _evaluateVerificationDecision(result, actionName);

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showAlertDialog('Error', 'An unexpected SDK error occurred: $e');
    }
  }

  void _evaluateVerificationDecision(LivenessResult result, String actionName) {
    if (result.success) {
      if (result.status == LivenessStatus.pass) {
        _showActionSuccessDialog(actionName, result);
      } else if (result.status == LivenessStatus.mediumRisk) {
        // Require Step-up OTP (Section 10 Medium Risk rule)
        _showStepUpOtpDialog(actionName, result);
      }
    } else {
      String failMessage = 'Verification failed or was cancelled.';
      if (result.status == LivenessStatus.lowConfidence) {
        failMessage = 'Low liveness confidence (${result.confidence}%). Action blocked for fraud prevention.';
      } else if (result.status == LivenessStatus.fail) {
        failMessage = 'Liveness validation failed. Security incident alert triggered.';
      }
      
      _showAlertDialog('Security Block', failMessage, isSuccess: false);
    }
  }

  void _showActionSuccessDialog(String actionName, LivenessResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The requested action "$actionName" has been authorized.', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Confidence: ${result.confidence}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Session ID: ${result.sessionId}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Complete', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStepUpOtpDialog(String actionName, LivenessResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amberAccent),
            SizedBox(width: 10),
            Text('Step-Up OTP Required', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medium Risk detected (Confidence 80%-94%). An OTP has been sent to your registered number.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter 6-Digit OTP',
                hintText: '123456',
              ),
            ),
            const SizedBox(height: 10),
            Text('Session ID: ${result.sessionId}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action authorized via Step-up OTP!')),
              );
            },
            child: const Text('Verify OTP'),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isSuccess ? const Color(0xFF00E676) : Colors.redAccent,
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kolomoni Digital Banking'),
        centerTitle: true,
        backgroundColor: const Color(0xFF171B26),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Promotional Banner / Identity HUD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identity Assurance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Biometric Liveness SDK provides enterprise-grade anti-spoof checks on high-risk banking operations.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // SDK Configuration Panel
            const Text(
              'SDK TESTING PANEL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white38),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171B26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Simulate Offline Mode (Forced Mock)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Uses local MockLivenessProvider UI instead of the API backend'),
                    value: _forceMock,
                    activeColor: const Color(0xFF00E676),
                    onChanged: (val) {
                      setState(() {
                        _forceMock = val;
                      });
                      _initializeSDK();
                    },
                  ),
                  if (!_forceMock) ...[
                    const Divider(height: 24, color: Colors.white12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'FastAPI Backend URL',
                        border: OutlineInputBorder(),
                        hintText: 'http://localhost:8000',
                      ),
                      controller: TextEditingController()..text = _backendUrl,
                      onChanged: (val) {
                        _backendUrl = val;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Demo Actions
            const Text(
              'INTEGRATION USE CASES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white38),
            ),
            const SizedBox(height: 10),
            _UseCaseCard(
              title: 'Onboarding (New Registration)',
              description: 'Run liveness audit check before registering a new user profile.',
              icon: Icons.person_add_outlined,
              color: const Color(0xFF2979FF),
              onTap: () => _triggerVerification('Account Onboarding'),
            ),
            const SizedBox(height: 12),
            _UseCaseCard(
              title: 'Reset Transaction PIN',
              description: 'Require passive facial audit prior to granting secure PIN updates.',
              icon: Icons.lock_reset_outlined,
              color: Colors.purpleAccent,
              onTap: () => _triggerVerification('Transaction PIN Reset'),
            ),
            const SizedBox(height: 12),
            _UseCaseCard(
              title: 'High-Value Transfer',
              description: 'Initiate step-up verification before transferring funds above limit.',
              icon: Icons.monetization_on_outlined,
              color: Colors.amberAccent,
              onTap: () => _triggerVerification('High-Value Fund Transfer'),
            ),
            const SizedBox(height: 30),

            // Last Verification Log
            if (_lastResult != null) ...[
              const Text(
                'LATEST AUDIT RESULT LOG',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white38),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lastResult!.success
                      ? const Color(0xFF00E676).withOpacity(0.08)
                      : Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastResult!.success
                        ? const Color(0xFF00E676).withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'STATUS: ${_lastResult!.status.name.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _lastResult!.success ? const Color(0xFF00E676) : Colors.redAccent,
                          ),
                        ),
                        Text(
                          '${_lastResult!.confidence}% Confidence',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Session ID: ${_lastResult!.sessionId}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    Text('Provider: ${_lastResult!.provider}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (_lastResult!.imageReference.isNotEmpty)
                      Text('Audit Image Ref: ${_lastResult!.imageReference}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (_lastResult!.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text('Error Details: ${_lastResult!.errorMessage}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UseCaseCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UseCaseCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171B26),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}
