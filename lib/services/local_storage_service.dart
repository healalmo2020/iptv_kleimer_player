import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';

enum PlayerEngine { vlc, mediaKit }

class LocalStorageService {
  const LocalStorageService();

  Box<dynamic> get _settings => Hive.box<dynamic>(AppConstants.settingsBox);
  Box<dynamic> get _playback => Hive.box<dynamic>(AppConstants.playbackBox);
  Box<dynamic> get _favorites => Hive.box<dynamic>(AppConstants.favoritesBox);
  Box<dynamic> get _history => Hive.box<dynamic>(AppConstants.historyBox);

  PlayerEngine getPlayerEngine() {
    final value = _settings.get('player_engine', defaultValue: 'vlc') as String;
    return value == 'media_kit' ? PlayerEngine.mediaKit : PlayerEngine.vlc;
  }

  Future<void> setPlayerEngine(PlayerEngine engine) async {
    await _settings.put('player_engine', engine == PlayerEngine.mediaKit ? 'media_kit' : 'vlc');
  }

  Future<void> saveFavorite(String streamId, Map<String, dynamic> payload) async {
    await _favorites.put(streamId, payload);
  }

  Future<void> removeFavorite(String streamId) async {
    await _favorites.delete(streamId);
  }

  bool isFavorite(String streamId) {
    return _favorites.containsKey(streamId);
  }

  List<Map<String, dynamic>> getFavorites() {
    return _favorites.values.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }

  Future<void> savePlaybackProgress(String contentId, Duration progress, Duration total) async {
    await _playback.put(contentId, {
      'positionMs': progress.inMilliseconds,
      'durationMs': total.inMilliseconds,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getPlaybackProgress(String contentId) {
    final value = _playback.get(contentId);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, Map<String, dynamic>> getAllPlaybackProgress() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _playback.keys) {
      final value = _playback.get(key);
      if (key is String && value is Map) {
        result[key] = Map<String, dynamic>.from(value);
      }
    }
    return result;
  }

  Future<void> saveLastChannel(String streamId) async {
    await _settings.put('last_channel', streamId);
  }

  String? getLastChannel() {
    final value = _settings.get('last_channel');
    return value is String ? value : null;
  }

  Future<void> saveHistoryItem(Map<String, dynamic> item) async {
    final existing = _history.get('items', defaultValue: <Map<String, dynamic>>[]) as List<dynamic>;
    final mutable = existing.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    mutable.removeWhere((e) => e['id'] == item['id']);
    mutable.insert(0, item);
    await _history.put('items', mutable.take(100).toList(growable: false));
  }

  List<Map<String, dynamic>> getHistory() {
    final items = _history.get('items', defaultValue: <Map<String, dynamic>>[]) as List<dynamic>;
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }
}
