import '../../domain/entities/entry.dart';

abstract class EntriesRepository {
  Future<void> dispose();

  Stream<Entry?> watchEntryForDate(DateTime date);

  Stream<Entry?> watchEntryForDateId(String dateId);

  Stream<List<Entry>> watchEntriesForMonth(DateTime month);

  Stream<List<Entry>> watchEntriesForRange({
    required DateTime from,
    required DateTime to,
  });

  Future<void> upsertEntryForDate({
    required DateTime date,
    required String text,
    required int rating,
  });

  Future<void> upsertEntryForDateId({
    required String dateId,
    required String text,
    required int rating,
  });

  Future<void> deleteEntryForDateId(String dateId);

  Stream<Entry?> watchTodayEntry();

  Future<void> upsertTodayEntry({required String text, required int rating});

  Future<String> addTodayImage({required String filePath});

  Future<List<String>> addTodayImages({required List<String> filePaths});

  Future<EntryFileAttachment> addTodayFile({
    required String filePath,
    required String name,
    required int sizeBytes,
  });

  Future<EntryLocation> addTodayLocation({
    required double lat,
    required double lng,
    required double accuracyMeters,
  });

  Future<EntryMusicAttachment> addTodayMusic({required String input});

  Future<String> addImageForDate({
    required DateTime date,
    required String filePath,
  });

  Future<List<String>> addImagesForDate({
    required DateTime date,
    required List<String> filePaths,
  });

  Future<EntryFileAttachment> addFileForDate({
    required DateTime date,
    required String filePath,
    required String name,
    required int sizeBytes,
  });

  Future<void> removeImageForDateId({
    required String dateId,
    required String imageUrl,
  });

  Future<void> removeFileForDateId({
    required String dateId,
    required EntryFileAttachment file,
  });

  Future<void> removeLocationForDateId(String dateId);

  Future<EntryLocation> addLocationForDate({
    required DateTime date,
    required double lat,
    required double lng,
    required double accuracyMeters,
  });

  Future<EntryMusicAttachment> addMusicForDate({
    required DateTime date,
    required String input,
    String? title,
  });

  Future<void> removeMusicForDateId(String dateId);
}
