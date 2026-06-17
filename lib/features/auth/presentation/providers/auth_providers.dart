import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/firebase_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(auth: ref.watch(firebaseAuthProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchAuthState();
});

/// Watches `users/{uid}` and returns whether onboarding is completed.
final onboardingCompletedProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  final db = ref.watch(firestoreProvider);
  return db.collection('users').doc(user.uid).snapshots().map((snap) {
    final data = snap.data();
    return (data?['onboardingCompleted'] as bool?) ?? false;
  });
});
