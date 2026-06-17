enum PeriodType { week, month }

String periodTypeToString(PeriodType t) => switch (t) {
  PeriodType.week => 'week',
  PeriodType.month => 'month',
};

PeriodType periodTypeFromString(String v) => switch (v) {
  'week' => PeriodType.week,
  'month' => PeriodType.month,
  _ => throw FormatException('Unknown PeriodType', v),
};

class PeriodAnalysis {
  const PeriodAnalysis({
    required this.id,
    required this.periodType,
    required this.fromDateId,
    required this.toDateId,
    required this.entryDateIds,
    required this.avgRating,
    required this.summary,
    required this.model,
    required this.createdAt,
  });

  final String id;
  final PeriodType periodType;
  final String fromDateId;
  final String toDateId;
  final List<String> entryDateIds;
  final double avgRating;
  final String summary;
  final String model;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
    'periodType': periodTypeToString(periodType),
    'fromDateId': fromDateId,
    'toDateId': toDateId,
    'entryDateIds': entryDateIds,
    'avgRating': avgRating,
    'summary': summary,
    'model': model,
    'createdAt': createdAt?.millisecondsSinceEpoch,
  };
}
