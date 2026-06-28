import 'package:flutter_test/flutter_test.dart';
import 'package:me_mine/core/location/place_label.dart';
import 'package:me_mine/features/journal/domain/entities/entry.dart';

void main() {
  group('displayPlaceLabel', () {
    test('returns stored place label when available', () {
      const location = EntryLocation(
        lat: 50.45,
        lng: 30.52,
        accuracyMeters: 12,
        placeLabel: 'Khreshchatyk St, Kyiv',
      );

      expect(displayPlaceLabel(location), 'Khreshchatyk St, Kyiv');
    });

    test('falls back to saved location when label is missing', () {
      const location = EntryLocation(
        lat: 50.45,
        lng: 30.52,
        accuracyMeters: 12,
      );

      expect(displayPlaceLabel(location), 'Saved location');
    });
  });
}
