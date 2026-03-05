import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_stream.dart';
import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController(this._storage)
      : super(_storage.getFavorites().map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toSet());

  final LocalStorageService _storage;

  bool isFavorite(String streamId) => state.contains(streamId);

  Future<void> toggle(LiveStream stream) async {
    return toggleByPayload(
      streamId: stream.id,
      payload: {
        'id': stream.id,
        'name': stream.name,
        'iconUrl': stream.iconUrl,
        'categoryId': stream.categoryId,
        'epgChannelId': stream.epgChannelId,
      },
    );
  }

  Future<void> toggleByPayload({
    required String streamId,
    required Map<String, dynamic> payload,
  }) async {
    if (state.contains(streamId)) {
      await _storage.removeFavorite(streamId);
      state = {...state}..remove(streamId);
      return;
    }

    await _storage.saveFavorite(streamId, payload);
    state = {...state, streamId};
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesController, Set<String>>((ref) {
  return FavoritesController(ref.watch(localStorageProvider));
});
