import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_page_routes.dart';
import 'passcode_hash.dart';
import 'passcode_prefs.dart';
import 'passcode_setup_screen.dart';
import 'passcode_storage.dart';

class PasscodeSettingsScreen extends ConsumerWidget {
  const PasscodeSettingsScreen({super.key});

  Future<bool> _verifyPinDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Enter current PIN'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () async {
                      final p = ctrl.text.trim();
                      if (!isFourDigitPin(p)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter 4 digits.')),
                        );
                        return;
                      }
                      final stored = await readPasscodeHash();
                      if (!ctx.mounted) return;
                      if (stored != hashAppPasscode(p)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Wrong PIN.')),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Continue'),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
      return ok == true;
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final ok = await _verifyPinDialog(context);
    if (!ok || !context.mounted) return;
    await clearPasscodeHash();
    await ref.read(passcodePrefsProvider.notifier).clearAll();
    ref.read(passcodeSessionUnlockedProvider.notifier).unlock();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App passcode turned off.')));
    }
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      appModalFadeRoute<bool>(
        const PasscodeSetupScreen(mode: PasscodeSetupMode.create),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App passcode enabled.')));
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final ok = await _verifyPinDialog(context);
    if (!ok || !context.mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      appModalFadeRoute<bool>(
        const PasscodeSetupScreen(mode: PasscodeSetupMode.change),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passcode updated.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(passcodePrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App passcode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Require PIN'),
            subtitle: const Text(
              'Locks the journal when the app goes to the background. '
              'Off by default.',
            ),
            value: prefs.enabled && prefs.pinConfigured,
            onChanged: (on) async {
              if (on) {
                await _enable(context, ref);
              } else {
                await _disable(context, ref);
              }
            },
          ),
          if (prefs.shouldLockShell) ...[
            SwitchListTile(
              title: const Text('Offer biometrics on unlock'),
              subtitle: const Text('Face ID / fingerprint when available.'),
              value: prefs.allowBiometricUnlock,
              onChanged: (v) {
                ref
                    .read(passcodePrefsProvider.notifier)
                    .setAllowBiometricUnlock(v);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePin(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
