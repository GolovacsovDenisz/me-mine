import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/period_analysis.dart';
import '../../domain/repositories/period_analysis_repository.dart';
import '../mappers/period_analysis_mapper.dart';

class PeriodAnalysisRepositoryImpl implements PeriodAnalysisRepository {
  PeriodAnalysisRepositoryImpl({
    required FirebaseFirestore db,
    required AsyncValue<User?> authState,
  }) : _db = db,
       _authState = authState;

  final FirebaseFirestore _db;
  final AsyncValue<User?> _authState;

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

  @override
  Stream<PeriodAnalysis?> watchAnalysis(String analysisId) {
    final user = _authState.value;
    if (user == null) return Stream.value(null);

    return _ref(uid: user.uid, analysisId: analysisId).snapshots().map(
      (doc) => doc.exists ? PeriodAnalysisMapper.fromDoc(doc) : null,
    );
  }

  @override
  Future<void> upsertAnalysis({required PeriodAnalysis analysis}) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    await _ref(uid: user.uid, analysisId: analysis.id).set(
      PeriodAnalysisMapper.toFirestore(analysis),
      SetOptions(merge: true),
    );
  }
}
