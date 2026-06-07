import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'user_ai_profile.dart';

/// Live profile slice for AI / Train AI screen.
final userAiProfileProvider = StreamProvider<UserAiProfile>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return const Stream<UserAiProfile>.empty();
  }
  final db = ref.watch(firestoreProvider);
  return db.collection('users').doc(user.uid).snapshots().map((snap) {
    if (!snap.exists) {
      return const UserAiProfile(
        openAnswers: {},
        aiCustomPrompt: '',
        aiTone: UserAiProfile.friendlyTone,
      );
    }
    return UserAiProfile.fromSnapshot(snap);
  });
});
