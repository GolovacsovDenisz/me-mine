import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'passcode_hash.dart';
import 'passcode_prefs.dart';
import 'passcode_storage.dart';

enum PasscodeSetupMode { create, change }

/// Create a new 4-digit PIN or replace it (`change` keeps prefs enabled).
class PasscodeSetupScreen extends ConsumerStatefulWidget {
  const PasscodeSetupScreen({super.key, this.mode = PasscodeSetupMode.create});

  final PasscodeSetupMode mode;

  @override
  ConsumerState<PasscodeSetupScreen> createState() =>
      _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends ConsumerState<PasscodeSetupScreen> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _first.text.trim();
    final b = _second.text.trim();
    setState(() => _error = null);
    if (!isFourDigitPin(a) || !isFourDigitPin(b)) {
      setState(() => _error = 'Use exactly 4 digits.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      final hash = hashAppPasscode(a);
      await writePasscodeHash(hash);
      if (widget.mode == PasscodeSetupMode.create) {
        await ref
            .read(passcodePrefsProvider.notifier)
            .markPinConfiguredAndEnabled();
      }
      ref.read(passcodeSessionUnlockedProvider.notifier).unlock();
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == PasscodeSetupMode.create
        ? 'Create app passcode'
        : 'Choose a new passcode';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.mode == PasscodeSetupMode.create
                  ? 'Pick a 4-digit PIN to lock the journal when you leave the app.'
                  : 'Enter a new 4-digit PIN twice.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _first,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _second,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
