import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic hash for a 4-digit app passcode (never store plaintext).
String hashAppPasscode(String fourDigits) {
  final normalized = fourDigits.trim();
  final bytes = utf8.encode('me_mine_app_passcode_v1|$normalized');
  return sha256.convert(bytes).toString();
}

bool isFourDigitPin(String s) {
  final t = s.trim();
  return RegExp(r'^\d{4}$').hasMatch(t);
}
