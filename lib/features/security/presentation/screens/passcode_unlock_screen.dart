import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/datasources/passcode_prefs.dart';
import '../../data/datasources/passcode_storage.dart';
import '../../domain/value_objects/passcode_hash.dart';

class PasscodeUnlockScreen extends ConsumerStatefulWidget {
  const PasscodeUnlockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<PasscodeUnlockScreen> createState() =>
      _PasscodeUnlockScreenState();
}

class _PasscodeUnlockScreenState extends ConsumerState<PasscodeUnlockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _pin.text.trim();
    setState(() => _error = null);
    if (!isFourDigitPin(raw)) {
      setState(() => _error = 'Enter your 4-digit PIN.');
      return;
    }
    setState(() => _busy = true);
    try {
      final stored = await readPasscodeHash();
      final ok = stored != null && stored == hashAppPasscode(raw);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Wrong PIN.');
        _pin.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    final prefs = ref.read(passcodePrefsProvider);
    if (!prefs.allowBiometricUnlock) return;
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return;
    if (!await auth.canCheckBiometrics) return;
    setState(() => _busy = true);
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Me Mine',
        biometricOnly: true,
      );
      if (ok && mounted) widget.onUnlocked();
    } on LocalAuthException {
      // Cancelled or failed.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(passcodePrefsProvider);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'App locked',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your PIN to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
                  ),
                  if (prefs.allowBiometricUnlock) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _biometric,
                      child: const Text('Use biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
