import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/entry.dart';

abstract final class EntryMapper {
  static Entry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return Entry(
      id: doc.id,
      dateId: (data['date'] as String?) ?? doc.id,
      text: (data['text'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      imageUrls: ((data['imageUrls'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      localImagePaths: const [],
      files: ((data['files'] as List?) ?? const [])
          .map(EntryFileAttachment.fromMap)
          .whereType<EntryFileAttachment>()
          .toList(growable: false),
      location: EntryLocation.fromMap(data['location']),
      music: EntryMusicAttachment.fromMap(data['music']),
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
    );
  }
}
