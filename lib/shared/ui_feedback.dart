import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_motion_widgets.dart';

/// Short, user-readable copy for SnackBars and full-screen error states.
String userFacingErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final code = error.code.toLowerCase();
    if (code == 'not-found') {
      return 'Cloud Function "analyzePeriod" was not found for this app '
          'project/region. Deploy Functions from the repo root '
          '(firebase deploy --only functions) and ensure the Firebase '
          'project matches google-services.json / firebase_options.dart.';
    }
    final m = error.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return error.code;
  }
  if (error is FirebaseAuthException) {
    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : _firebaseAuthCodeMessage(error.code);
  }
  if (error is FirebaseException) {
    final m = error.message?.trim();
    if (m != null && m.isNotEmpty) return m;
    return error.code;
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  final s = error.toString();
  if (s.contains('TimeoutException') || s.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }
  return s;
}

String _firebaseAuthCodeMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No account found for this email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Wrong email or password.';
    case 'email-already-in-use':
      return 'This email is already registered.';
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'weak-password':
      return 'Password is too weak (try at least 6 characters).';
    case 'network-request-failed':
      return 'Network error. Check your connection.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment and try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    default:
      return 'Something went wrong ($code).';
  }
}

/// Empty / zero-data placeholder (Material 3 friendly).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: FadeInAppear(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: scheme.outline),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Firestore / network failure with optional retry.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.title = 'Couldn’t load data',
    this.onRetry,
  });

  final Object error;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msg = userFacingErrorMessage(error);
    return Center(
      child: FadeInAppear(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.danger.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
