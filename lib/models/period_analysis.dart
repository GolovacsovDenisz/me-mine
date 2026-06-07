import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String fromDateId; // yyyy-mm-dd
  final String toDateId; // yyyy-mm-dd
  final List<String> entryDateIds; // yyyy-mm-dd, sorted
  final double avgRating; // 0..5
  final String summary;
  final String model;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
    'periodType': periodTypeToString(periodType),
    'fromDateId': fromDateId,
    'toDateId': toDateId,
    'entryDateIds':
        entryDateIds, // читай "имя которое будет на базе" : 'обект дарт любого типа'
    'avgRating': avgRating,
    'summary': summary,
    'model': model,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
  };

  static PeriodAnalysis fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final typeRaw = data['periodType'];
    final from = data['fromDateId'];
    final to = data['toDateId'];
    final model = data['model'];

    PeriodType periodType = PeriodType.week;
    if (typeRaw is String) {
      try {
        periodType = periodTypeFromString(typeRaw);
      } on FormatException {
        periodType = PeriodType.week;
      }
    }

    return PeriodAnalysis(
      id: doc.id,
      periodType: periodType,
      fromDateId: from is String ? from : '',
      toDateId: to is String ? to : '',
      entryDateIds: ((data['entryDateIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0,
      summary: (data['summary'] as String?) ?? '',
      model: model is String ? model : '',
      createdAt: asDate(data['createdAt']),
    );
  }
}
