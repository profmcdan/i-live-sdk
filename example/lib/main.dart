import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kolomoni_liveness_sdk/kolomoni_liveness_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liveness Demo',
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
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  bool _forceMock = false;
  LivenessResult? _lastResult;
  bool _isProcessing = false;

  late final TextEditingController _userIdController;
  late final TextEditingController _backendUrlController;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController(text: 'cst_user_8855');
    _backendUrlController = TextEditingController(text: 'http://10.0.2.2:8000');
    _initializeSDK();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _initializeSDK() async {
    try {
      await LivenessSDK.initialize(
        backendUrl: _backendUrlController.text,
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
      final result = await LivenessSDK.verify(
        context,
        userId: _userIdController.text,
        verificationType: 'VERIFICATION',
      );
      
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

  void _showOnboardingFormDialog() {
    final formKey = GlobalKey<FormState>();
    final bvnController = TextEditingController(text: '22233344455');
    final emailController = TextEditingController(text: 'new_user@example.com');
    final phoneController = TextEditingController(text: '+2348012345678');
    String selectedChannel = 'personal';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isRegistering = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Color(0xFF2979FF)),
                  SizedBox(width: 10),
                  Text('Customer Onboarding', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Provide customer details to create a record on the backend before biometric verification.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: bvnController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'BVN (11 Digits)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'BVN is required';
                          if (value.length != 11 || int.tryParse(value) == null) {
                            return 'BVN must be exactly 11 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedChannel,
                        dropdownColor: const Color(0xFF171B26),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Onboarding Channel',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'personal', child: Text('Personal')),
                          DropdownMenuItem(value: 'business', child: Text('Business')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedChannel = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email is required';
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Phone number is required';
                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isRegistering ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isRegistering
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isRegistering = true;
                              errorMessage = null;
                            });

                            try {
                              // Register customer on the backend
                              final customer = await _registerCustomerOnBackend(
                                bvn: bvnController.text,
                                email: emailController.text,
                                phone: phoneController.text,
                                channel: selectedChannel,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop(); // Close dialog
                                _triggerVerificationOnboarding(
                                  customerId: customer['customer_id'] as String,
                                  bvn: customer['bvn'] as String,
                                  channel: customer['channel'] as String,
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isRegistering = false;
                                errorMessage = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2979FF)),
                  child: isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Register & Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _registerCustomerOnBackend({
    required String bvn,
    required String email,
    required String phone,
    required String channel,
  }) async {
    final url = Uri.parse('${_backendUrlController.text}/api/v1/liveness/customer');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bvn': bvn,
        'email': email,
        'phone': phone,
        'channel': channel,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to register customer record.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _triggerVerificationOnboarding({
    required String customerId,
    required String bvn,
    required String channel,
  }) async {
    setState(() {
      _isProcessing = true;
    });

    // Re-initialize config to capture toggles
    await _initializeSDK();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting liveness audit for: Onboarding Registration'),
        duration: Duration(milliseconds: 1000),
      ),
    );

    try {
      final result = await LivenessSDK.verify(
        context,
        userId: customerId,
        bvn: bvn,
        verificationType: 'ONBOARDING',
        channel: channel,
      );

      setState(() {
        _lastResult = result;
        _isProcessing = false;
      });

      _evaluateVerificationDecision(result, 'Account Onboarding');
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showAlertDialog('Error', 'An unexpected SDK error occurred: $e');
    }
  }

  void _showFaceVerificationDialog() {
    final formKey = GlobalKey<FormState>();
    final userIdController = TextEditingController(text: _userIdController.text);
    String selectedChannel = 'personal';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isVerifying = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.face_retouching_natural, color: Color(0xFF22C7D6)),
                  SizedBox(width: 10),
                  Text('Face Verification', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Provide your user ID to match your current face check against your onboarded reference profile.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: userIdController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Customer UUID / User ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'User ID is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedChannel,
                        dropdownColor: const Color(0xFF171B26),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Verification Channel',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'personal', child: Text('Personal')),
                          DropdownMenuItem(value: 'business', child: Text('Business')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedChannel = val;
                            });
                          }
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.of(context).pop(); // Close dialog
                            _triggerFaceVerification(
                              userId: userIdController.text,
                              channel: selectedChannel,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C7D6)),
                  child: const Text('Verify Face', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _triggerFaceVerification({
    required String userId,
    required String channel,
  }) async {
    setState(() {
      _isProcessing = true;
    });

    await _initializeSDK();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting Face Verification check...'),
        duration: Duration(milliseconds: 1000),
      ),
    );

    try {
      final result = await LivenessSDK.verify(
        context,
        userId: userId,
        verificationType: 'VERIFICATION',
        channel: channel,
      );

      setState(() {
        _lastResult = result;
        _isProcessing = false;
      });

      _evaluateVerificationDecision(result, 'Face Verification Linkage');
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
        title: const Text('FaceGuard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF171B26),
        elevation: 0,
        bottom: _isProcessing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4.0),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2979FF)),
                ),
              )
            : null,
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
                  TextField(
                    enabled: !_isProcessing,
                    decoration: const InputDecoration(
                      labelText: 'User ID for Tracking',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. cst_user_8855',
                    ),
                    controller: _userIdController,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: !_isProcessing,
                    decoration: const InputDecoration(
                      labelText: 'FastAPI Backend URL',
                      border: OutlineInputBorder(),
                      hintText: 'http://localhost:8000',
                    ),
                    controller: _backendUrlController,
                  ),
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
              onTap: _isProcessing ? null : () => _showOnboardingFormDialog(),
            ),
            const SizedBox(height: 12),
            _UseCaseCard(
              title: 'Account Face Verification',
              description: 'Compare current face live capture against your registered onboarding face profile.',
              icon: Icons.face_retouching_natural,
              color: const Color(0xFF22C7D6),
              onTap: _isProcessing ? null : () => _showFaceVerificationDialog(),
            ),
            const SizedBox(height: 12),
            _UseCaseCard(
              title: 'Reset Transaction PIN',
              description: 'Require passive facial audit prior to granting secure PIN updates.',
              icon: Icons.lock_reset_outlined,
              color: Colors.purpleAccent,
              onTap: _isProcessing ? null : () => _triggerVerification('Transaction PIN Reset'),
            ),
            const SizedBox(height: 12),
            _UseCaseCard(
              title: 'High-Value Transfer',
              description: 'Initiate step-up verification before transferring funds above limit.',
              icon: Icons.monetization_on_outlined,
              color: Colors.amberAccent,
              onTap: _isProcessing ? null : () => _triggerVerification('High-Value Fund Transfer'),
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
                      ? const Color(0xFF00E676).withValues(alpha: 0.08)
                      : Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastResult!.success
                        ? const Color(0xFF00E676).withValues(alpha: 0.3)
                        : Colors.redAccent.withValues(alpha: 0.3),
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
  final VoidCallback? onTap;

  const _UseCaseCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Card(
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
                    color: color.withValues(alpha: 0.1),
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
      ),
    );
  }
}
