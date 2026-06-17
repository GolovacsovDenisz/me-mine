import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../journal/domain/entities/entry.dart';
import '../../../journal/presentation/providers/entries_providers.dart';

final monthEntriesProvider = StreamProvider.family<List<Entry>, DateTime>((
  ref,
  month,
) {
  final repo = ref.watch(entriesRepositoryProvider);
  return repo.watchEntriesForMonth(month);
});
