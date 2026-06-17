import '../../domain/entities/period_analysis.dart';

abstract class PeriodAnalysisRepository {
  Stream<PeriodAnalysis?> watchAnalysis(String analysisId);

  Future<void> upsertAnalysis({required PeriodAnalysis analysis});
}
