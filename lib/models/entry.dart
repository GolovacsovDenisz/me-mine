import 'package:cloud_firestore/cloud_firestore.dart';

class EntryFileAttachment {
  const EntryFileAttachment({
    required this.name,
    required this.url,
    required this.sizeBytes,
  });

  final String name;
  final String url;
  final int sizeBytes;

  Map<String, Object?> toMap() => {
    'name': name,
    'url': url,
    'sizeBytes': sizeBytes,
  };

  static EntryFileAttachment? fromMap(Object? v) {
    if (v is! Map) return null;
    final name = v['name'];
    final url = v['url'];
    final size = v['sizeBytes'];
    if (name is! String || url is! String) return null;
    final sizeBytes = (size is num) ? size.toInt() : 0;
    return EntryFileAttachment(name: name, url: url, sizeBytes: sizeBytes);
  }
}

class EntryLocation {
  const EntryLocation({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    this.placeLabel,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;

  /// Human-readable place (street / area), not raw coordinates.
  final String? placeLabel;

  Map<String, Object?> toMap() => {
    'lat': lat,
    'lng': lng,
    'accuracyMeters': accuracyMeters,
    if (placeLabel != null && placeLabel!.trim().isNotEmpty)
      'placeLabel': placeLabel!.trim(),
  };

  static EntryLocation? fromMap(Object? v) {
    if (v is! Map) return null;
    final lat = v['lat'];
    final lng = v['lng'];
    final acc = v['accuracyMeters'];
    if (lat is! num || lng is! num) return null;
    final accuracy = (acc is num) ? acc.toDouble() : 0.0;
    final label = v['placeLabel'];
    return EntryLocation(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracyMeters: accuracy,
      placeLabel: label is String ? label.trim() : null,
    );
  }
}

class EntryMusicAttachment {
  const EntryMusicAttachment({
    required this.videoId,
    required this.sourceUrl,
    this.title,
    this.thumbnailUrl,
  });

  final String videoId;
  final String sourceUrl;
  final String? title;
  final String? thumbnailUrl;

  Map<String, Object?> toMap() => {
    'provider': 'youtube',
    'videoId': videoId,
    'sourceUrl': sourceUrl,
    if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
      'thumbnailUrl': thumbnailUrl!.trim(),
  };

  static EntryMusicAttachment? fromMap(Object? v) {
    if (v is! Map) return null;
    final videoId = v['videoId'];
    final sourceUrl = v['sourceUrl'];
    if (videoId is! String || sourceUrl is! String) return null;
    final title = v['title'];
    final thumbnailUrl = v['thumbnailUrl'];
    return EntryMusicAttachment(
      videoId: videoId.trim(),
      sourceUrl: sourceUrl.trim(),
      title: title is String ? title.trim() : null,
      thumbnailUrl: thumbnailUrl is String ? thumbnailUrl.trim() : null,
    );
  }
}

/// A single journal entry for one calendar day.
///
/// In this app we use **one entry per day**, so Firestore doc id is typically
/// the date string `yyyy-mm-dd`.
class Entry {
  const Entry({
    required this.id,
    required this.dateId,
    required this.text,
    required this.rating,
    required this.imageUrls,
    required this.localImagePaths,
    required this.files,
    required this.location,
    required this.music,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String dateId;
  final String text;
  final int rating; // 1..5
  final List<String> imageUrls;
  final List<String> localImagePaths;
  final List<EntryFileAttachment> files;
  final EntryLocation? location;
  final EntryMusicAttachment? music;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<String> get imageSources =>
      localImagePaths.isNotEmpty ? localImagePaths : imageUrls;

  Map<String, Object?> toMap() {
    return {
      'date': dateId,
      'text': text,
      'rating': rating,
      'imageUrls': imageUrls,
      'localImagePaths': localImagePaths,
      'files': files.map((f) => f.toMap()).toList(growable: false),
      'location': location?.toMap(),
      'music': music?.toMap(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

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
