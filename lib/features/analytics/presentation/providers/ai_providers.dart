import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/cloud_function_ai_service.dart';
import '../../domain/services/ai_service.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  return CloudFunctionAiService();
});
