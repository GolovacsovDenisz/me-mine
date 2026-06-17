import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/period_analysis_repository.dart';
import '../../data/repositories/period_analysis_repository_impl.dart';

final periodAnalysisRepositoryProvider = Provider<PeriodAnalysisRepository>((
  ref,
) {
  return PeriodAnalysisRepositoryImpl(
    db: ref.watch(firestoreProvider),
    authState: ref.watch(authStateProvider),
  );
});
