import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class PlayerEngineController extends StateNotifier<PlayerEngine> {
  PlayerEngineController(this._storage) : super(_storage.getPlayerEngine());

  final LocalStorageService _storage;

  Future<void> setEngine(PlayerEngine engine) async {
    state = engine;
    await _storage.setPlayerEngine(engine);
  }
}

final playerEngineProvider = StateNotifierProvider<PlayerEngineController, PlayerEngine>((ref) {
  return PlayerEngineController(ref.watch(localStorageProvider));
});
