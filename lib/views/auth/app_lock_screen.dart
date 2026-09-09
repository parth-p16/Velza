import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velza/services/app_lock_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  final AppLockService _appLockService = AppLockService();
  String _enteredPin = '';
  String _errorMessage = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Auto-prompt biometric if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appLockService.isBiometricEnabled) {
        _triggerBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerBiometrics() async {
    final success = await _appLockService.authenticateWithBiometrics();
    if (!success && mounted) {
      // User can still type PIN
    }
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 6) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4 || _enteredPin.length == 6) {
      _verifyCurrentPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _verifyCurrentPin() async {
    final success = await _appLockService.verifyPin(_enteredPin);
    if (!success) {
      if (_enteredPin.length == 4) {
        // If 4 digits failed, wait if user is entering a 6 digit PIN, but if 6 digits or after a brief pause:
        return;
      }
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation while locked
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0B16),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),

              // Header
              Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.lock_outline_rounded, color: Color(0xFFD4AF37), size: 36),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Velza Locked',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your security PIN to continue',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 24),

                  // PIN indicator dots with shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * (_shakeController.isAnimating ? 1 : 0), 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFFD4AF37) : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? const Color(0xFFD4AF37) : Colors.white38,
                              width: 1.8,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),

                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),

              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 20.0),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 18),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 18),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric or empty
                        _appLockService.isBiometricEnabled
                            ? _buildActionButton(
                                icon: Icons.fingerprint_rounded,
                                onPressed: _triggerBiometrics,
                              )
                            : const SizedBox(width: 72, height: 72),

                        _buildNumberKey('0'),

                        _buildActionButton(
                          icon: Icons.backspace_outlined,
                          onPressed: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberKey(d)).toList(),
    );
  }

  Widget _buildNumberKey(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(36),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(icon, color: const Color(0xFFD4AF37), size: 28),
        ),
      ),
    );
  }
}
