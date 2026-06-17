import 'package:geocoding/geocoding.dart';

import 'package:me_mine/features/journal/domain/entities/entry.dart';

/// Reverse-geocode coordinates into a short street / area label.
Future<String?> resolvePlaceLabel({
  required double lat,
  required double lng,
}) async {
  try {
    final marks = await placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return null;
    final p = marks.first;
    final parts = <String>[
      if (p.street != null && p.street!.trim().isNotEmpty) p.street!.trim(),
      if (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
        p.subLocality!.trim(),
      if (p.locality != null && p.locality!.trim().isNotEmpty)
        p.locality!.trim(),
    ];
    if (parts.isEmpty) {
      final name = p.name?.trim();
      if (name != null && name.isNotEmpty) return name;
      return null;
    }
    return parts.take(2).join(', ');
  } catch (_) {
    return null;
  }
}

String displayPlaceLabel(EntryLocation location) {
  final label = location.placeLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  return 'Saved location';
}
