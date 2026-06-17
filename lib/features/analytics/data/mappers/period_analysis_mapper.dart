import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/period_analysis.dart';

abstract final class PeriodAnalysisMapper {
  static PeriodAnalysis fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
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

  static Map<String, Object?> toFirestore(PeriodAnalysis analysis) {
    return {
      'periodType': periodTypeToString(analysis.periodType),
      'fromDateId': analysis.fromDateId,
      'toDateId': analysis.toDateId,
      'entryDateIds': analysis.entryDateIds,
      'avgRating': analysis.avgRating,
      'summary': analysis.summary,
      'model': analysis.model,
      if (analysis.createdAt != null)
        'createdAt': Timestamp.fromDate(analysis.createdAt!),
    };
  }
}
