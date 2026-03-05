import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'favorites_provider.dart';

final favoritesItemsProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(favoritesProvider);
  return ref.watch(localStorageProvider).getFavorites();
});

final historyItemsProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(localStorageProvider).getHistory();
});

final continueWatchingProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final history = storage.getHistory();
  final progressMap = storage.getAllPlaybackProgress();

  final result = <Map<String, dynamic>>[];
  for (final item in history) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) {
      continue;
    }

    final progress = progressMap[id];
    if (progress == null) {
      continue;
    }

    final positionMs = (progress['positionMs'] as int?) ?? 0;
    final durationMs = (progress['durationMs'] as int?) ?? 0;
    if (durationMs <= 0 || positionMs <= 0 || positionMs >= durationMs) {
      continue;
    }

    result.add({...item, ...progress});
  }

  return result;
});
