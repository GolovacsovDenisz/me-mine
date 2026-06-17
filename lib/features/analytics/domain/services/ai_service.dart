class PeriodAiInput {
  const PeriodAiInput({
    required this.periodId,
    required this.periodType,
    required this.fromDateId,
    required this.toDateId,
    required this.force,
  });

  /// Firestore doc id in `users/{uid}/period_analyses/{periodId}`.
  final String periodId;

  /// `'week' | 'month'`
  final String periodType;
  final String fromDateId;
  final String toDateId;

  /// True when user presses Regenerate.
  final bool force;
}

class PeriodAiOutput {
  const PeriodAiOutput({required this.model, required this.summary});

  final String model;
  final String summary;
}

abstract class AiService {
  Future<PeriodAiOutput> analyzePeriod(PeriodAiInput input);
}
