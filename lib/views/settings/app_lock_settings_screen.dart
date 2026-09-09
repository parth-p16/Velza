import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velza/services/app_lock_service.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final AppLockService _appLockService = AppLockService();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  void _checkBiometricSupport() async {
    final supported = await _appLockService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _canUseBiometrics = supported;
      });
    }
  }

  void _showSetPinDialog({required bool isChanging}) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String error = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isChanging ? 'Change Security PIN' : 'Set Security PIN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Enter 4-Digit PIN',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Confirm 4-Digit PIN',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmPinController.text.trim();
                  if (pin.length != 4) {
                    setDialogState(() {
                      error = 'PIN must be exactly 4 digits.';
                    });
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() {
                      error = 'PINs do not match.';
                    });
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _appLockService.setupPin(
                    pin: pin,
                    enableBiometrics: _canUseBiometrics,
                  );
                  if (mounted) {
                    setState(() {});
                    messenger.showSnackBar(
                      SnackBar(content: Text(isChanging ? 'PIN updated successfully' : 'App Lock enabled')),
                    );
                  }
                },
                child: const Text('Save PIN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDisableConfirmDialog() {
    final pinController = TextEditingController();
    String error = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Disable App Lock?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter your current PIN to turn off App Lock:'),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final pin = pinController.text.trim();
                  final valid = await _appLockService.verifyPin(pin);
                  if (!valid) {
                    setDialogState(() {
                      error = 'Incorrect PIN.';
                    });
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _appLockService.disableLock();
                  if (mounted) {
                    setState(() {});
                    messenger.showSnackBar(
                      const SnackBar(content: Text('App Lock disabled')),
                    );
                  }
                },
                child: const Text('Disable', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = _appLockService.isLockEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Lock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _appLockService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E162B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLocked ? const Color(0xFFD4AF37).withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable App Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Require PIN or fingerprint to open Velza'),
                      value: _appLockService.isLockEnabled,
                      activeThumbColor: const Color(0xFFD4AF37),
                      onChanged: (val) {
                        if (val) {
                          _showSetPinDialog(isChanging: false);
                        } else {
                          _showDisableConfirmDialog();
                        }
                      },
                    ),
                    if (isLocked) ...[
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.pin_rounded, color: Color(0xFFD4AF37)),
                        title: const Text('Change PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Update your 4-digit security PIN'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showSetPinDialog(isChanging: true),
                      ),
                      if (_canUseBiometrics) ...[
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Unlock with Biometrics', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Use fingerprint or face recognition'),
                          value: _appLockService.isBiometricEnabled,
                          activeThumbColor: const Color(0xFFD4AF37),
                          onChanged: (val) async {
                            await _appLockService.updateBiometricSetting(val);
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              if (isLocked) ...[
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    'AUTOMATICALLY LOCK',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E162B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildTimeoutRadio('Immediately', 'immediately'),
                      const Divider(height: 1),
                      _buildTimeoutRadio('After 1 minute', '1_min'),
                      const Divider(height: 1),
                      _buildTimeoutRadio('After 5 minutes', '5_min'),
                      const Divider(height: 1),
                      _buildTimeoutRadio('After 15 minutes', '15_min'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'When enabled, Velza locks when leaving the app or according to your chosen timeout. Your PIN is cryptographically salted and hashed securely on your device.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeoutRadio(String label, String value) {
    final isSelected = _appLockService.timeoutSetting == value;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37))
          : const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey),
      onTap: () async {
        await _appLockService.updateTimeoutSetting(value);
        setState(() {});
      },
    );
  }
}
