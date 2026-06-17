import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/entry.dart';
import '../../domain/repositories/entries_repository.dart';
import '../../data/datasources/local_entries_store.dart';
import '../../data/repositories/entries_repository_impl.dart';

final localEntriesStoreProvider = Provider<LocalEntriesStore>((ref) {
  final store = LocalEntriesStore();
  ref.onDispose(store.dispose);
  return store;
});

final entriesRepositoryProvider = Provider<EntriesRepository>((ref) {
  final repo = EntriesRepositoryImpl(
    db: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
    authState: ref.watch(authStateProvider),
    localStore: ref.watch(localEntriesStoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Watch a single day entry by `yyyy-mm-dd` document id.
final entryByDateIdProvider = StreamProvider.family<Entry?, String>((
  ref,
  dateId,
) {
  final repo = ref.watch(entriesRepositoryProvider);
  return repo.watchEntryForDateId(dateId);
});
