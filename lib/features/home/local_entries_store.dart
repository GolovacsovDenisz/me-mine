import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/entry.dart';

const entrySyncPending = 'pending';
const entrySyncSynced = 'synced';

class LocalEntriesStore {
  Database? _db;
  final _changes = StreamController<void>.broadcast();

  Future<void> dispose() async {
    await _changes.close();
    await _db?.close();
  }

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbPath, 'me_mine_entries.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE local_entries (
            uid TEXT NOT NULL,
            date_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (uid, date_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX local_entries_uid_date ON local_entries(uid, date_id)',
        );
        await db.execute(
          'CREATE INDEX local_entries_uid_sync ON local_entries(uid, sync_status)',
        );
      },
    );
    _db = db;
    return db;
  }

  Stream<Entry?> watchEntry({
    required String uid,
    required String dateId,
  }) async* {
    yield await getEntry(uid: uid, dateId: dateId);
    await for (final _ in _changes.stream) {
      yield await getEntry(uid: uid, dateId: dateId);
    }
  }

  Stream<List<Entry>> watchEntriesForRange({
    required String uid,
    required String fromDateId,
    required String toDateId,
  }) async* {
    yield await getEntriesForRange(
      uid: uid,
      fromDateId: fromDateId,
      toDateId: toDateId,
    );
    await for (final _ in _changes.stream) {
      yield await getEntriesForRange(
        uid: uid,
        fromDateId: fromDateId,
        toDateId: toDateId,
      );
    }
  }

  Future<Entry?> getEntry({required String uid, required String dateId}) async {
    final row = await _rowFor(uid: uid, dateId: dateId);
    if (row == null) return null;
    return _entryFromPayload(row['payload'] as String);
  }

  Future<List<Entry>> getEntriesForRange({
    required String uid,
    required String fromDateId,
    required String toDateId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'local_entries',
      where: 'uid = ? AND date_id >= ? AND date_id <= ?',
      whereArgs: [uid, fromDateId, toDateId],
      orderBy: 'date_id ASC',
    );
    return rows
        .map((row) => _entryFromPayload(row['payload'] as String))
        .toList(growable: false);
  }

  Future<List<Entry>> pendingEntries(String uid) async {
    final db = await _database;
    final rows = await db.query(
      'local_entries',
      where: 'uid = ? AND sync_status = ?',
      whereArgs: [uid, entrySyncPending],
      orderBy: 'updated_at ASC',
    );
    return rows
        .map((row) => _entryFromPayload(row['payload'] as String))
        .toList(growable: false);
  }

  Future<String?> syncStatus({
    required String uid,
    required String dateId,
  }) async {
    final row = await _rowFor(uid: uid, dateId: dateId);
    return row?['sync_status'] as String?;
  }

  Future<void> upsertLocal({
    required String uid,
    required Entry entry,
    required String syncStatus,
  }) async {
    final db = await _database;
    await db.insert('local_entries', {
      'uid': uid,
      'date_id': entry.dateId,
      'payload': jsonEncode(_entryToPayload(entry)),
      'sync_status': syncStatus,
      'updated_at': (entry.updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.add(null);
  }

  Future<void> upsertRemote({
    required String uid,
    required Entry remote,
  }) async {
    final status = await syncStatus(uid: uid, dateId: remote.dateId);
    final local = await getEntry(uid: uid, dateId: remote.dateId);
    if (local != null && status == entrySyncPending) {
      await upsertLocal(
        uid: uid,
        entry: Entry(
          id: local.id,
          dateId: local.dateId,
          text: local.text,
          rating: local.rating,
          imageUrls: remote.imageUrls,
          localImagePaths: local.localImagePaths,
          files: remote.files,
          location: local.location ?? remote.location,
          music: local.music ?? remote.music,
          createdAt: local.createdAt ?? remote.createdAt,
          updatedAt: local.updatedAt ?? remote.updatedAt,
        ),
        syncStatus: entrySyncPending,
      );
      return;
    }

    await upsertLocal(uid: uid, entry: remote, syncStatus: entrySyncSynced);
  }

  Future<void> markSynced({required String uid, required Entry entry}) {
    return upsertLocal(uid: uid, entry: entry, syncStatus: entrySyncSynced);
  }

  Future<void> deleteEntry({
    required String uid,
    required String dateId,
  }) async {
    final db = await _database;
    await db.delete(
      'local_entries',
      where: 'uid = ? AND date_id = ?',
      whereArgs: [uid, dateId],
    );
    _changes.add(null);
  }

  Future<Map<String, Object?>?> _rowFor({
    required String uid,
    required String dateId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'local_entries',
      where: 'uid = ? AND date_id = ?',
      whereArgs: [uid, dateId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Map<String, Object?> _entryToPayload(Entry entry) {
    return {
      'id': entry.id,
      'date': entry.dateId,
      'text': entry.text,
      'rating': entry.rating,
      'imageUrls': entry.imageUrls,
      'localImagePaths': entry.localImagePaths,
      'files': entry.files.map((f) => f.toMap()).toList(growable: false),
      'location': entry.location?.toMap(),
      'music': entry.music?.toMap(),
      'createdAt': entry.createdAt?.millisecondsSinceEpoch,
      'updatedAt': entry.updatedAt?.millisecondsSinceEpoch,
    };
  }

  static Entry _entryFromPayload(String payload) {
    final data = jsonDecode(payload) as Map<String, Object?>;
    DateTime? asDate(Object? value) {
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    return Entry(
      id: (data['id'] as String?) ?? (data['date'] as String? ?? ''),
      dateId: (data['date'] as String?) ?? (data['id'] as String? ?? ''),
      text: (data['text'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      imageUrls: ((data['imageUrls'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      localImagePaths: ((data['localImagePaths'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
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
