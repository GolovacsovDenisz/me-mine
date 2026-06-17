/// User profile fields used for AI personalization.
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
}
