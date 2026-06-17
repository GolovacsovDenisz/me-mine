import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../onboarding/domain/constants/onboarding_questions.dart';
import '../../domain/entities/user_ai_profile.dart';

abstract final class UserAiProfileMapper {
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
    final tone = rawTone == UserAiProfile.criticTone
        ? UserAiProfile.criticTone
        : UserAiProfile.friendlyTone;
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

  static Map<String, dynamic> toFirestoreUpdate({
    required Map<String, String> openAnswers,
    required String aiCustomPrompt,
    required String aiTone,
  }) {
    return {
      'onboardingOpenAnswers': openAnswers,
      'aiCustomPrompt': aiCustomPrompt.trim(),
      'aiTone': aiTone == UserAiProfile.criticTone
          ? UserAiProfile.criticTone
          : UserAiProfile.friendlyTone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
