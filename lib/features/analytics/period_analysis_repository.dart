import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/period_analysis.dart';
import '../auth/auth_providers.dart';

final periodAnalysisRepositoryProvider = Provider<PeriodAnalysisRepository>((
  ref,
) {
  return PeriodAnalysisRepository(
    db: ref.watch(firestoreProvider),
    authState: ref.watch(authStateProvider),
  );
});

class PeriodAnalysisRepository {
  PeriodAnalysisRepository({
    required FirebaseFirestore db,
    required AsyncValue authState,
  }) : _db = db,
       _authState = authState;

  final FirebaseFirestore _db;
  final AsyncValue _authState;

  DocumentReference<Map<String, dynamic>> _ref({
    required String uid,
    required String analysisId,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('period_analyses')
        .doc(analysisId);
  }

  Stream<PeriodAnalysis?> watchAnalysis(String analysisId) {
    final user = _authState.value;
    if (user == null) return Stream.value(null);

    return _ref(
      uid: user.uid,
      analysisId: analysisId,
    ).snapshots().map((doc) => doc.exists ? PeriodAnalysis.fromDoc(doc) : null);
  }

  Future<void> upsertAnalysis({required PeriodAnalysis analysis}) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    await _ref(
      uid: user.uid,
      analysisId: analysis.id,
    ).set(analysis.toMap(), SetOptions(merge: true));
  }
}
