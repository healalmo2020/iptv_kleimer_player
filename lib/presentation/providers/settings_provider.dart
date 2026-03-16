import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../services/local_storage_service.dart';
import '../../domain/entities/player_engine.dart';
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

  static bool get _supportsVlc {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static PlayerEngine _normalizeForPlatform(PlayerEngine engine) {
    if (!_supportsVlc && engine == PlayerEngine.vlc) {
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

class PlayerBufferProfileController extends StateNotifier<PlayerBufferProfile> {
  PlayerBufferProfileController(this._storage)
      : super(_storage.getPlayerBufferProfile());

  final LocalStorageService _storage;

  Future<void> setProfile(PlayerBufferProfile profile) async {
    state = profile;
    await _storage.setPlayerBufferProfile(profile);
  }
}

final playerBufferProfileProvider =
    StateNotifierProvider<PlayerBufferProfileController, PlayerBufferProfile>((
      ref,
    ) {
      return PlayerBufferProfileController(ref.watch(localStorageProvider));
    });
