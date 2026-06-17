import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEnabled = 'passcode_enabled';
const _kPinConfigured = 'passcode_pin_configured';
const _kBiometric = 'passcode_biometric_unlock';

class PasscodePrefs {
  const PasscodePrefs({
    required this.enabled,
    required this.pinConfigured,
    required this.allowBiometricUnlock,
  });

  final bool enabled;
  final bool pinConfigured;
  final bool allowBiometricUnlock;

  bool get shouldLockShell => enabled && pinConfigured;
}

final passcodePrefsProvider =
    NotifierProvider<PasscodePrefsNotifier, PasscodePrefs>(
      PasscodePrefsNotifier.new,
    );

class PasscodePrefsNotifier extends Notifier<PasscodePrefs> {
  @override
  PasscodePrefs build() {
    Future<void>.delayed(Duration.zero, _load);
    return const PasscodePrefs(
      enabled: false,
      pinConfigured: false,
      allowBiometricUnlock: true,
    );
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = PasscodePrefs(
      enabled: p.getBool(_kEnabled) ?? false,
      pinConfigured: p.getBool(_kPinConfigured) ?? false,
      allowBiometricUnlock: p.getBool(_kBiometric) ?? true,
    );
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, state.enabled);
    await p.setBool(_kPinConfigured, state.pinConfigured);
    await p.setBool(_kBiometric, state.allowBiometricUnlock);
  }

  Future<void> markPinConfiguredAndEnabled() async {
    state = PasscodePrefs(
      enabled: true,
      pinConfigured: true,
      allowBiometricUnlock: state.allowBiometricUnlock,
    );
    await _persist();
  }

  Future<void> clearAll() async {
    state = const PasscodePrefs(
      enabled: false,
      pinConfigured: false,
      allowBiometricUnlock: true,
    );
    final p = await SharedPreferences.getInstance();
    await p.remove(_kEnabled);
    await p.remove(_kPinConfigured);
    await p.setBool(_kBiometric, true);
  }

  Future<void> setAllowBiometricUnlock(bool value) async {
    state = PasscodePrefs(
      enabled: state.enabled,
      pinConfigured: state.pinConfigured,
      allowBiometricUnlock: value,
    );
    await _persist();
  }
}

/// Session-only: unlocked after PIN / biometrics until app goes to background.
final passcodeSessionUnlockedProvider =
    NotifierProvider<PasscodeSessionNotifier, bool>(
      PasscodeSessionNotifier.new,
    );

class PasscodeSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}
