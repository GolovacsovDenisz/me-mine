import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/location/place_label.dart';
import '../../domain/entities/entry.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../domain/utils/journal_date_utils.dart';
import '../../domain/utils/music_attachment_utils.dart';
import '../datasources/local_entries_store.dart';
import '../mappers/entry_mapper.dart';

class EntriesRepositoryImpl implements EntriesRepository {
  EntriesRepositoryImpl({
    required FirebaseFirestore db,
    required FirebaseStorage storage,
    required AsyncValue<User?> authState,
    required LocalEntriesStore localStore,
  }) : _db = db,
       _storage = storage,
       _authState = authState,
       _localStore = localStore;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final AsyncValue<User?> _authState;
  final LocalEntriesStore _localStore;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _rangeSubscriptions = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _entrySubscriptions = {};
  bool _syncingPending = false;

  @override
  Future<void> dispose() async {
    for (final sub in _rangeSubscriptions.values) {
      await sub.cancel();
    }
    for (final sub in _entrySubscriptions.values) {
      await sub.cancel();
    }
  }

  DocumentReference<Map<String, dynamic>> _entryRef({
    required String uid,
    required String dateId,
  }) {
    return _db.collection('users').doc(uid).collection('entries').doc(dateId);
  }

  /// Watch the entry for a given day (usually today).
  Stream<Entry?> watchEntryForDate(DateTime date) {
    final user = _authState.value;
    if (user == null) return Stream.value(null);

    final id = JournalDateUtils.dateId(date);
    return watchEntryForDateId(id);
  }

  /// Watch the entry by `yyyy-mm-dd` document id.
  Stream<Entry?> watchEntryForDateId(String dateId) {
    final user = _authState.value;
    if (user == null) return Stream.value(null);

    _watchRemoteEntry(uid: user.uid, dateId: dateId);
    unawaited(_syncPendingForUser(user.uid));
    return _localStore.watchEntry(uid: user.uid, dateId: dateId);
  }

  /// Watch all entries within a month.
  ///
  /// Uses the `date` field (`yyyy-mm-dd`) to query a range like:
  /// `2026-05-01` ... `2026-05-31`.
  Stream<List<Entry>> watchEntriesForMonth(DateTime month) {
    final user = _authState.value;
    if (user == null) return Stream.value(const []);

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final startId = JournalDateUtils.dateId(firstDay);
    final endId = JournalDateUtils.dateId(lastDay);

    _watchRemoteRange(uid: user.uid, startId: startId, endId: endId);
    unawaited(_syncPendingForUser(user.uid));
    return _localStore.watchEntriesForRange(
      uid: user.uid,
      fromDateId: startId,
      toDateId: endId,
    );
  }

  Stream<List<Entry>> watchEntriesForRange({
    required DateTime from,
    required DateTime to,
  }) {
    if (to.isBefore(from)) {
      throw ArgumentError.value(to, 'to', 'must be after from');
    }

    final startId = JournalDateUtils.dateId(from);
    final endId = JournalDateUtils.dateId(to);
    final user = _authState.value;

    if (user == null) return Stream.value(const []);

    _watchRemoteRange(uid: user.uid, startId: startId, endId: endId);
    unawaited(_syncPendingForUser(user.uid));
    return _localStore.watchEntriesForRange(
      uid: user.uid,
      fromDateId: startId,
      toDateId: endId,
    );
  }

  /// Save (upsert) the entry for a day. Because we use one entry per day,
  /// this overwrites the existing doc for that date.
  Future<void> upsertEntryForDate({
    required DateTime date,
    required String text,
    required int rating,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final id = JournalDateUtils.dateId(date);
    final existing = await _localEntryOrEmpty(uid: user.uid, dateId: id);
    final updated = _copyEntry(existing, text: text, rating: rating);
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(_syncEntryToRemote(uid: user.uid, entry: updated));
  }

  /// Upsert by explicit `yyyy-mm-dd` id (for editing past days from Home/Calendar).
  Future<void> upsertEntryForDateId({
    required String dateId,
    required String text,
    required int rating,
  }) async {
    final day = JournalDateUtils.tryParseDateId(dateId);
    if (day == null) {
      throw ArgumentError.value(dateId, 'dateId', 'expected yyyy-mm-dd');
    }
    await upsertEntryForDate(date: day, text: text, rating: rating);
  }

  /// Deletes the Firestore document for that day (text/rating/urls in doc removed).
  /// Storage objects under `users/.../entries/{dateId}/` are not bulk-deleted here.
  Future<void> deleteEntryForDateId(String dateId) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');
    await _localStore.deleteEntry(uid: user.uid, dateId: dateId);
    unawaited(_entryRef(uid: user.uid, dateId: dateId).delete());
  }

  /// Convenience helpers for the “daily entry” screen.
  Stream<Entry?> watchTodayEntry() => watchEntryForDate(DateTime.now());

  Future<void> upsertTodayEntry({required String text, required int rating}) =>
      upsertEntryForDate(date: DateTime.now(), text: text, rating: rating);

  Future<String> addTodayImage({required String filePath}) =>
      addImageForDate(date: DateTime.now(), filePath: filePath);

  Future<List<String>> addTodayImages({required List<String> filePaths}) =>
      addImagesForDate(date: DateTime.now(), filePaths: filePaths);

  Future<EntryFileAttachment> addTodayFile({
    required String filePath,
    required String name,
    required int sizeBytes,
  }) => addFileForDate(
    date: DateTime.now(),
    filePath: filePath,
    name: name,
    sizeBytes: sizeBytes,
  );

  Future<EntryLocation> addTodayLocation({
    required double lat,
    required double lng,
    required double accuracyMeters,
  }) => addLocationForDate(
    date: DateTime.now(),
    lat: lat,
    lng: lng,
    accuracyMeters: accuracyMeters,
  );

  Future<EntryMusicAttachment> addTodayMusic({required String input}) =>
      addMusicForDate(date: DateTime.now(), input: input);

  Future<String> addImageForDate({
    required DateTime date,
    required String filePath,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final id = JournalDateUtils.dateId(date);
    final file = await _prepareLocalImage(
      input: File(filePath),
      uid: user.uid,
      dateId: id,
    );
    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: id);
    final localPaths = [...entry.localImagePaths, file.path];
    final updated = _copyEntry(entry, localImagePaths: localPaths);
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(
      _uploadLocalImage(uid: user.uid, dateId: id, localPath: file.path),
    );
    return file.path;
  }

  Future<void> _uploadLocalImage({
    required String uid,
    required String dateId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) return;

    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final storageRef = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('entries')
        .child(dateId)
        .child('images')
        .child(name);

    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();

    final ref = _entryRef(uid: uid, dateId: dateId);
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'date': dateId,
      'imageUrls': FieldValue.arrayUnion([url]),
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));

    final entry = await _localEntryOrEmpty(uid: uid, dateId: dateId);
    final imageUrls = entry.imageUrls.contains(url)
        ? entry.imageUrls
        : [...entry.imageUrls, url];
    await _localStore.upsertLocal(
      uid: uid,
      entry: _copyEntry(entry, imageUrls: imageUrls),
      syncStatus: entry.localImagePaths.isEmpty
          ? entrySyncSynced
          : entrySyncPending,
    );
  }

  /// Uploads multiple images sequentially; returns download URLs in order.
  Future<List<String>> addImagesForDate({
    required DateTime date,
    required List<String> filePaths,
  }) async {
    final urls = <String>[];
    for (final path in filePaths) {
      urls.add(await addImageForDate(date: date, filePath: path));
    }
    return urls;
  }

  Future<EntryFileAttachment> addFileForDate({
    required DateTime date,
    required String filePath,
    required String name,
    required int sizeBytes,
  }) async {
    const maxBytes = 10 * 1024 * 1024; // 10MB
    if (sizeBytes > maxBytes) {
      throw StateError('File is too large. Max size is 10MB.');
    }

    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final id = JournalDateUtils.dateId(date);
    final file = File(filePath);
    final safeName = _sanitizeFilename(name);
    final storageName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final storageRef = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('entries')
        .child(id)
        .child('files')
        .child(storageName);

    await storageRef.putFile(file);
    final url = await storageRef.getDownloadURL();

    final attachment = EntryFileAttachment(
      name: name,
      url: url,
      sizeBytes: sizeBytes,
    );

    final ref = _entryRef(uid: user.uid, dateId: id);
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'date': id,
      'files': FieldValue.arrayUnion([attachment.toMap()]),
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));

    return attachment;
  }

  Future<void> removeImageForDateId({
    required String dateId,
    required String imageUrl,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: dateId);
    final isRemote =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final updated = _copyEntry(
      entry,
      imageUrls: entry.imageUrls.where((url) => url != imageUrl).toList(),
      localImagePaths: entry.localImagePaths
          .where((path) => path != imageUrl)
          .toList(),
    );
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );

    if (!isRemote) {
      unawaited(() async {
        try {
          await File(imageUrl).delete();
        } catch (_) {
          // Local cache file may already be gone.
        }
      }());
      return;
    }

    unawaited(() async {
      final ref = _entryRef(uid: user.uid, dateId: dateId);
      await ref.update({
        'imageUrls': FieldValue.arrayRemove([imageUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _tryDeleteStorageUrl(imageUrl);
    }());
  }

  Future<void> removeFileForDateId({
    required String dateId,
    required EntryFileAttachment file,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final ref = _entryRef(uid: user.uid, dateId: dateId);
    await ref.update({
      'files': FieldValue.arrayRemove([file.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: dateId);
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: _copyEntry(
        entry,
        files: entry.files
            .where((f) => f.url != file.url)
            .toList(growable: false),
      ),
      syncStatus: entrySyncPending,
    );
    await _tryDeleteStorageUrl(file.url);
  }

  Future<void> removeLocationForDateId(String dateId) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: dateId);
    final updated = _copyEntry(
      entry,
      location: _OptionalValue<EntryLocation?>.some(null),
    );
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(_syncEntryToRemote(uid: user.uid, entry: updated));
  }

  Future<EntryLocation> addLocationForDate({
    required DateTime date,
    required double lat,
    required double lng,
    required double accuracyMeters,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final id = JournalDateUtils.dateId(date);
    final location = EntryLocation(
      lat: lat,
      lng: lng,
      accuracyMeters: accuracyMeters,
    );

    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: id);
    final updated = _copyEntry(
      entry,
      location: _OptionalValue<EntryLocation?>.some(location),
    );
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(
      _syncLocationWithLabel(uid: user.uid, dateId: id, location: location),
    );

    return location;
  }

  Future<void> _syncLocationWithLabel({
    required String uid,
    required String dateId,
    required EntryLocation location,
  }) async {
    final placeLabel = await resolvePlaceLabel(
      lat: location.lat,
      lng: location.lng,
    );
    final labeled = EntryLocation(
      lat: location.lat,
      lng: location.lng,
      accuracyMeters: location.accuracyMeters,
      placeLabel: placeLabel,
    );
    final entry = await _localEntryOrEmpty(uid: uid, dateId: dateId);
    final updated = _copyEntry(
      entry,
      location: _OptionalValue<EntryLocation?>.some(labeled),
    );
    await _localStore.upsertLocal(
      uid: uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    await _syncEntryToRemote(uid: uid, entry: updated);
  }

  Future<EntryMusicAttachment> addMusicForDate({
    required DateTime date,
    required String input,
    String? title,
  }) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final videoId = extractYoutubeVideoId(input);
    if (videoId == null) {
      throw ArgumentError.value(
        input,
        'input',
        'expected a YouTube or YouTube Music link',
      );
    }

    final music = EntryMusicAttachment(
      videoId: videoId,
      sourceUrl: youtubeWatchUrl(videoId),
      title: title,
      thumbnailUrl: youtubeThumbnailUrl(videoId),
    );

    final id = JournalDateUtils.dateId(date);
    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: id);
    final updated = _copyEntry(
      entry,
      music: _OptionalValue<EntryMusicAttachment?>.some(music),
    );
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(_syncEntryToRemote(uid: user.uid, entry: updated));

    return music;
  }

  Future<void> removeMusicForDateId(String dateId) async {
    final user = _authState.value;
    if (user == null) throw StateError('Not signed in');

    final entry = await _localEntryOrEmpty(uid: user.uid, dateId: dateId);
    final updated = _copyEntry(
      entry,
      music: _OptionalValue<EntryMusicAttachment?>.some(null),
    );
    await _localStore.upsertLocal(
      uid: user.uid,
      entry: updated,
      syncStatus: entrySyncPending,
    );
    unawaited(_syncEntryToRemote(uid: user.uid, entry: updated));
  }

  void _watchRemoteEntry({required String uid, required String dateId}) {
    final key = '$uid:$dateId';
    if (_entrySubscriptions.containsKey(key)) return;

    _entrySubscriptions[key] = _entryRef(uid: uid, dateId: dateId)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) return;
          unawaited(
            _localStore.upsertRemote(uid: uid, remote: EntryMapper.fromDoc(doc)),
          );
        });
  }

  void _watchRemoteRange({
    required String uid,
    required String startId,
    required String endId,
  }) {
    final key = '$uid:$startId:$endId';
    if (_rangeSubscriptions.containsKey(key)) return;

    final query = _db
        .collection('users')
        .doc(uid)
        .collection('entries')
        .where('date', isGreaterThanOrEqualTo: startId)
        .where('date', isLessThanOrEqualTo: endId)
        .orderBy('date');

    _rangeSubscriptions[key] = query.snapshots().listen((snap) {
      for (final doc in snap.docs) {
        unawaited(
          _localStore.upsertRemote(uid: uid, remote: EntryMapper.fromDoc(doc)),
        );
      }
    });
  }

  Future<void> _syncPendingForUser(String uid) async {
    if (_syncingPending) return;
    _syncingPending = true;
    try {
      final pending = await _localStore.pendingEntries(uid);
      for (final entry in pending) {
        await _syncEntryToRemote(uid: uid, entry: entry);
      }
    } finally {
      _syncingPending = false;
    }
  }

  Future<void> _syncEntryToRemote({
    required String uid,
    required Entry entry,
  }) async {
    final ref = _entryRef(uid: uid, dateId: entry.dateId);
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'date': entry.dateId,
      'text': entry.text,
      'rating': entry.rating,
      'imageUrls': entry.imageUrls,
      'files': entry.files.map((f) => f.toMap()).toList(growable: false),
      if (entry.location != null) 'location': entry.location!.toMap(),
      if (entry.location == null) 'location': FieldValue.delete(),
      if (entry.music != null) 'music': entry.music!.toMap(),
      if (entry.music == null) 'music': FieldValue.delete(),
      'updatedAt': now,
      'createdAt': entry.createdAt ?? now,
    }, SetOptions(merge: true));

    if (entry.localImagePaths.isEmpty) {
      await _localStore.markSynced(uid: uid, entry: entry);
    }
  }

  Future<Entry> _localEntryOrEmpty({
    required String uid,
    required String dateId,
  }) async {
    final existing = await _localStore.getEntry(uid: uid, dateId: dateId);
    if (existing != null) return existing;
    final now = DateTime.now();
    return Entry(
      id: dateId,
      dateId: dateId,
      text: '',
      rating: 0,
      imageUrls: const [],
      localImagePaths: const [],
      files: const [],
      location: null,
      music: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Entry _copyEntry(
    Entry entry, {
    String? text,
    int? rating,
    List<String>? imageUrls,
    List<String>? localImagePaths,
    List<EntryFileAttachment>? files,
    _OptionalValue<EntryLocation?>? location,
    _OptionalValue<EntryMusicAttachment?>? music,
  }) {
    return Entry(
      id: entry.id,
      dateId: entry.dateId,
      text: text ?? entry.text,
      rating: rating ?? entry.rating,
      imageUrls: imageUrls ?? entry.imageUrls,
      localImagePaths: localImagePaths ?? entry.localImagePaths,
      files: files ?? entry.files,
      location: location == null ? entry.location : location.value,
      music: music == null ? entry.music : music.value,
      createdAt: entry.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static Future<File> _prepareLocalImage({
    required File input,
    required String uid,
    required String dateId,
  }) async {
    final compressed = await _compressImage(input);
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/entry_media/$uid/$dateId/images');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final out = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    return compressed.copy(out.path);
  }

  static Future<File> _compressImage(File input) async {
    // Keep it simple: recompress to JPEG for speed + cost savings.
    // Typical result: ~5-20x smaller than original camera images.
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/mm_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final outFile = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      quality: 80,
      minWidth: 1440,
      minHeight: 1440,
      format: CompressFormat.jpeg,
    );

    return outFile == null ? input : File(outFile.path);
  }

  Future<void> _tryDeleteStorageUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Object may already be gone or URL may be external.
    }
  }

  static String _sanitizeFilename(String name) {
    // Keep it simple and cross-platform safe.
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (cleaned.isEmpty) return 'file';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }
}

class _OptionalValue<T> {
  const _OptionalValue.some(this.value);

  final T value;
}
