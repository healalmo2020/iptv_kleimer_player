import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_storage_service.dart';
import 'app_providers.dart';

class PlayerPlaybackState {
  const PlayerPlaybackState({
    required this.playerInstanceNonce,
    required this.urlIndex,
    required this.currentPosition,
    required this.currentDuration,
    required this.dragPosition,
    required this.lastProgressAt,
    required this.lastPositionMs,
    required this.activeUrlsCount,
    required this.isPlaying,
    required this.isSeeking,
    required this.autoplayTriggered,
  });

  factory PlayerPlaybackState.initial() {
    return PlayerPlaybackState(
      playerInstanceNonce: 0,
      urlIndex: 0,
      currentPosition: Duration.zero,
      currentDuration: Duration.zero,
      dragPosition: Duration.zero,
      lastProgressAt: DateTime.now(),
      lastPositionMs: 0,
      activeUrlsCount: 1,
      isPlaying: true,
      isSeeking: false,
      autoplayTriggered: false,
    );
  }

  final int playerInstanceNonce;
  final int urlIndex;
  final Duration currentPosition;
  final Duration currentDuration;
  final Duration dragPosition;
  final DateTime lastProgressAt;
  final int lastPositionMs;
  final int activeUrlsCount;
  final bool isPlaying;
  final bool isSeeking;
  final bool autoplayTriggered;

  PlayerPlaybackState copyWith({
    int? playerInstanceNonce,
    int? urlIndex,
    Duration? currentPosition,
    Duration? currentDuration,
    Duration? dragPosition,
    DateTime? lastProgressAt,
    int? lastPositionMs,
    int? activeUrlsCount,
    bool? isPlaying,
    bool? isSeeking,
    bool? autoplayTriggered,
  }) {
    return PlayerPlaybackState(
      playerInstanceNonce: playerInstanceNonce ?? this.playerInstanceNonce,
      urlIndex: urlIndex ?? this.urlIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      currentDuration: currentDuration ?? this.currentDuration,
      dragPosition: dragPosition ?? this.dragPosition,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      activeUrlsCount: activeUrlsCount ?? this.activeUrlsCount,
      isPlaying: isPlaying ?? this.isPlaying,
      isSeeking: isSeeking ?? this.isSeeking,
      autoplayTriggered: autoplayTriggered ?? this.autoplayTriggered,
    );
  }
}

class PlayerPlaybackController extends StateNotifier<PlayerPlaybackState> {
  PlayerPlaybackController(this._storage)
    : super(PlayerPlaybackState.initial());

  final LocalStorageService _storage;

  Duration get seekBasePosition =>
      state.isSeeking ? state.dragPosition : state.currentPosition;

  void setActiveUrlsCount(int count) {
    final safeCount = count <= 0 ? 1 : count;
    if (safeCount == state.activeUrlsCount) {
      return;
    }
    state = state.copyWith(activeUrlsCount: safeCount);
  }

  Duration getInitialPosition(String streamId) {
    final savedProgress = _storage.getPlaybackProgress(streamId);
    return Duration(milliseconds: savedProgress?['positionMs'] as int? ?? 0);
  }

  Future<void> saveHistoryEntry({
    required String streamId,
    required String title,
    required String contentType,
    required String? extension,
  }) async {
    await _storage.saveLastChannel(streamId);
    await _storage.saveHistoryItem({
      'id': streamId,
      'title': title,
      'updatedAt': DateTime.now().toIso8601String(),
      'type': contentType,
      'ext': extension,
    });
  }

  Future<void> persistProgress(String streamId) async {
    if (state.currentDuration <= Duration.zero) {
      return;
    }

    await _storage.savePlaybackProgress(
      streamId,
      state.currentPosition,
      state.currentDuration,
    );
  }

  void setPlaying(bool value) {
    if (state.isPlaying == value) {
      return;
    }
    state = state.copyWith(isPlaying: value);
  }

  void beginSeek(Duration value) {
    state = state.copyWith(isSeeking: true, dragPosition: value);
  }

  Duration clampToDuration(Duration value) {
    final maxMs = state.currentDuration.inMilliseconds;
    if (maxMs <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: value.inMilliseconds.clamp(0, maxMs));
  }

  void completeSeek(Duration value) {
    state = state.copyWith(
      isSeeking: false,
      currentPosition: value,
      lastProgressAt: DateTime.now(),
    );
  }

  bool shouldReconnect(Duration threshold) {
    if (state.currentDuration <= Duration.zero) {
      return false;
    }
    return DateTime.now().difference(state.lastProgressAt) >= threshold;
  }

  bool onProgress({
    required Duration position,
    required Duration duration,
    required bool hasNextEpisode,
  }) {
    final currentMs = position.inMilliseconds;
    final progressed = currentMs > state.lastPositionMs;
    final nextLastProgressAt = progressed
        ? DateTime.now()
        : state.lastProgressAt;

    var shouldAutoplay = false;
    var nextAutoplayTriggered = state.autoplayTriggered;
    if (hasNextEpisode &&
        !nextAutoplayTriggered &&
        duration > const Duration(seconds: 1) &&
        position >= duration - const Duration(seconds: 2)) {
      nextAutoplayTriggered = true;
      shouldAutoplay = true;
    }

    state = state.copyWith(
      currentPosition: state.isSeeking ? state.currentPosition : position,
      currentDuration: duration,
      lastPositionMs: progressed ? currentMs : state.lastPositionMs,
      lastProgressAt: nextLastProgressAt,
      autoplayTriggered: nextAutoplayTriggered,
    );

    return shouldAutoplay;
  }

  bool consumeProgressAdvancedSince(int previousMs) {
    return state.lastPositionMs > previousMs;
  }

  void applyReconnectTrigger() {
    final nextUrlIndex = (state.urlIndex + 1) % state.activeUrlsCount;
    state = state.copyWith(
      urlIndex: nextUrlIndex,
      playerInstanceNonce: state.playerInstanceNonce + 1,
      lastProgressAt: DateTime.now(),
      isPlaying: true,
      isSeeking: false,
    );
  }
}

final playerPlaybackControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerPlaybackController, PlayerPlaybackState, String>((ref, key) {
      return PlayerPlaybackController(ref.watch(localStorageProvider));
    });
