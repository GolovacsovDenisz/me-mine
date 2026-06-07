import 'package:cloud_firestore/cloud_firestore.dart';

import '../onboarding/onboarding_questions.dart';

/// Firestore `users/{uid}` fields used for AI personalization.
class UserAiProfile {
  const UserAiProfile({
    required this.openAnswers,
    required this.aiCustomPrompt,
    required this.aiTone,
    this.legacyQuizAnswers,
  });

  static const friendlyTone = 'friendly';
  static const criticTone = 'critic';

  final Map<String, String> openAnswers;
  final String aiCustomPrompt;
  final String aiTone;
  final Map<String, dynamic>? legacyQuizAnswers;

  static UserAiProfile fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final raw = data['onboardingOpenAnswers'];
    final Map<String, String> open = {};
    if (raw is Map) {
      for (final k in kOnboardingOpenQuestionKeys) {
        final v = raw[k];
        if (v is String) open[k] = v;
      }
    }
    final custom = (data['aiCustomPrompt'] as String?)?.trim() ?? '';
    final rawTone = (data['aiTone'] as String?)?.trim();
    final tone = rawTone == criticTone ? criticTone : friendlyTone;
    final quiz = data['quizAnswers'];
    Map<String, dynamic>? legacy;
    if (quiz is Map) {
      legacy = Map<String, dynamic>.from(quiz);
    }
    return UserAiProfile(
      openAnswers: open,
      aiCustomPrompt: custom,
      aiTone: tone,
      legacyQuizAnswers: legacy,
    );
  }

  Map<String, dynamic> toFirestoreUpdate({
    required Map<String, String> openAnswers,
    required String aiCustomPrompt,
    required String aiTone,
  }) {
    return {
      'onboardingOpenAnswers': openAnswers,
      'aiCustomPrompt': aiCustomPrompt.trim(),
      'aiTone': aiTone == criticTone ? criticTone : friendlyTone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
