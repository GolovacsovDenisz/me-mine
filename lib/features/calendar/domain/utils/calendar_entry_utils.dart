import '../../../journal/domain/entities/entry.dart';

bool calendarDayHasEntry(Entry? entry) {
  if (entry == null) return false;
  return entry.text.trim().isNotEmpty ||
      entry.rating > 0 ||
      entry.imageSources.isNotEmpty ||
      entry.files.isNotEmpty ||
      entry.location != null ||
      entry.music != null;
}

bool calendarDayHasAttachment(Entry? entry) {
  if (entry == null) return false;
  return entry.imageSources.isNotEmpty ||
      entry.files.isNotEmpty ||
      entry.location != null ||
      entry.music != null;
}
