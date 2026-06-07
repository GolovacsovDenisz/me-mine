import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service.dart';
import 'cloud_function_ai_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  // “Adult” setup: Gemini is called from Cloud Functions.
  // The mobile app holds no Gemini API key.
  return CloudFunctionAiService();
});
