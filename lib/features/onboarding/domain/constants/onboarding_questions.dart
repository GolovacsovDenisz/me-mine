/// Seven open questions shown at onboarding and on the “Train AI” screen.
/// Answers are stored in Firestore under `users/{uid}.onboardingOpenAnswers`
/// as `open1` … `open7` and appended to AI prompts server-side.
const List<String> kOnboardingOpenQuestionKeys = [
  'open1',
  'open2',
  'open3',
  'open4',
  'open5',
  'open6',
  'open7',
];

const List<String> kOnboardingOpenQuestionLabels = [
  'Roughly how old are you?',
  'Where do you live (city / country)?',
  'What is your main occupation or role these days?',
  'What brings you to journaling right now?',
  'What tends to stress you the most lately?',
  'What helps you feel grounded or recharged?',
  'Anything else the assistant should know to support you better?',
];

String openAnswerKeyAt(int index) => kOnboardingOpenQuestionKeys[index];

String openQuestionLabelAt(int index) => kOnboardingOpenQuestionLabels[index];
