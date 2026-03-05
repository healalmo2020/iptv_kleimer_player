import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class PlayerEngineController extends StateNotifier<PlayerEngine> {
  PlayerEngineController(this._storage)
    : _savedEngine = _storage.getPlayerEngine(),
      super(_normalizeForPlatform(_storage.getPlayerEngine())) {
    if (_savedEngine != state) {
      Future.microtask(() => _storage.setPlayerEngine(state));
    }
  }

  final LocalStorageService _storage;
  final PlayerEngine _savedEngine;

  static PlayerEngine _normalizeForPlatform(PlayerEngine engine) {
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    if (isLinux && engine == PlayerEngine.vlc) {
      return PlayerEngine.mediaKit;
    }
    return engine;
  }

  Future<void> setEngine(PlayerEngine engine) async {
    final normalized = _normalizeForPlatform(engine);
    state = normalized;
    await _storage.setPlayerEngine(normalized);
  }
}

final playerEngineProvider =
    StateNotifierProvider<PlayerEngineController, PlayerEngine>((ref) {
      return PlayerEngineController(ref.watch(localStorageProvider));
    });
