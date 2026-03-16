import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';
import '../domain/entities/player_engine.dart';

enum PlayerBufferProfile { fast, balanced, stable }

class LocalStorageService {
  const LocalStorageService();

  static const String searchIndexSnapshotKey = 'search_index_snapshot_v1';
  static const String searchIndexSnapshotMetaKey =
      'search_index_snapshot_meta_v1';
  static const String dailyWarmupLastRunAtKey = 'daily_warmup_last_run_at_v1';
  static const String dailyWarmupLastRunUserKey =
      'daily_warmup_last_run_user_v1';

  Box<dynamic> get _settings => Hive.box<dynamic>(AppConstants.settingsBox);
  Box<dynamic> get _playback => Hive.box<dynamic>(AppConstants.playbackBox);
  Box<dynamic> get _favorites => Hive.box<dynamic>(AppConstants.favoritesBox);
  Box<dynamic> get _history => Hive.box<dynamic>(AppConstants.historyBox);

  PlayerEngine getPlayerEngine() {
    final value = _settings.get('player_engine', defaultValue: 'vlc') as String;
    return value == 'media_kit' ? PlayerEngine.mediaKit : PlayerEngine.vlc;
  }

  Future<void> setPlayerEngine(PlayerEngine engine) async {
    await _settings.put(
      'player_engine',
      engine == PlayerEngine.mediaKit ? 'media_kit' : 'vlc',
    );
  }

  PlayerBufferProfile getPlayerBufferProfile() {
    final value =
        _settings.get('player_buffer_profile', defaultValue: 'balanced')
            as String;
    return switch (value) {
      'fast' => PlayerBufferProfile.fast,
      'stable' => PlayerBufferProfile.stable,
      _ => PlayerBufferProfile.balanced,
    };
  }

  Future<void> setPlayerBufferProfile(PlayerBufferProfile profile) async {
    final value = switch (profile) {
      PlayerBufferProfile.fast => 'fast',
      PlayerBufferProfile.balanced => 'balanced',
      PlayerBufferProfile.stable => 'stable',
    };
    await _settings.put('player_buffer_profile', value);
  }

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _settings.put('username', username);
    await _settings.put('password', password);
  }

  ({String username, String password}) getSavedCredentials() {
    try {
      final username =
          _settings.get('username', defaultValue: AppConstants.defaultUsername)
              as String;
      final password =
          _settings.get('password', defaultValue: AppConstants.defaultPassword)
              as String;
      return (username: username, password: password);
    } catch (_) {
      return (
        username: AppConstants.defaultUsername,
        password: AppConstants.defaultPassword,
      );
    }
  }

  Future<void> saveFavorite(
    String streamId,
    Map<String, dynamic> payload,
  ) async {
    await _favorites.put(streamId, payload);
  }

  Future<void> removeFavorite(String streamId) async {
    await _favorites.delete(streamId);
  }

  bool isFavorite(String streamId) {
    return _favorites.containsKey(streamId);
  }

  List<Map<String, dynamic>> getFavorites() {
    return _favorites.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> savePlaybackProgress(
    String contentId,
    Duration progress,
    Duration total,
  ) async {
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

  bool isParentalEnabled() {
    return _settings.get('parental_enabled', defaultValue: false) as bool;
  }

  Future<void> setParentalEnabled(bool value) async {
    await _settings.put('parental_enabled', value);
  }

  String getParentalPin() {
    return _settings.get('parental_pin', defaultValue: '0000') as String;
  }

  Future<void> setParentalPin(String pin) async {
    await _settings.put('parental_pin', pin);
  }

  bool validateParentalPin(String pin) {
    return getParentalPin() == pin;
  }

  Future<void> saveHistoryItem(Map<String, dynamic> item) async {
    final existing =
        _history.get('items', defaultValue: <Map<String, dynamic>>[])
            as List<dynamic>;
    final mutable = existing
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    mutable.removeWhere((e) => e['id'] == item['id']);
    mutable.insert(0, item);
    await _history.put('items', mutable.take(100).toList(growable: false));
  }

  List<Map<String, dynamic>> getHistory() {
    final items =
        _history.get('items', defaultValue: <Map<String, dynamic>>[])
            as List<dynamic>;
    return items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> saveSearchIndexSnapshot(
    List<Map<String, dynamic>> items, {
    required int version,
  }) async {
    await _settings.put(searchIndexSnapshotKey, items);
    await _settings.put(searchIndexSnapshotMetaKey, {
      'version': version,
      'updatedAt': DateTime.now().toIso8601String(),
      'itemCount': items.length,
    });
  }

  List<Map<String, dynamic>> getSearchIndexSnapshot() {
    final value = _settings.get(
      searchIndexSnapshotKey,
      defaultValue: <Map<String, dynamic>>[],
    );
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<void> clearSearchIndexSnapshot() async {
    await _settings.delete(searchIndexSnapshotKey);
    await _settings.delete(searchIndexSnapshotMetaKey);
  }

  Map<String, dynamic>? getSearchIndexSnapshotMeta() {
    final value = _settings.get(searchIndexSnapshotMetaKey);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  bool shouldRunDailyWarmup({required String username, DateTime? now}) {
    final lastUser = _settings.get(dailyWarmupLastRunUserKey);
    if (lastUser is! String || lastUser.trim() != username.trim()) {
      return true;
    }

    final rawDate = _settings.get(dailyWarmupLastRunAtKey);
    if (rawDate is! String) {
      return true;
    }

    final lastRun = DateTime.tryParse(rawDate);
    if (lastRun == null) {
      return true;
    }

    final current = (now ?? DateTime.now()).toLocal();
    final lastLocal = lastRun.toLocal();
    return !_isSameLocalDate(lastLocal, current);
  }

  Future<void> markDailyWarmupRun({
    required String username,
    DateTime? executedAt,
  }) async {
    final now = executedAt ?? DateTime.now();
    await _settings.put(dailyWarmupLastRunAtKey, now.toIso8601String());
    await _settings.put(dailyWarmupLastRunUserKey, username.trim());
  }

  bool _isSameLocalDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
