import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerReconnectState {
  const PlayerReconnectState({
    required this.attemptsCompleted,
    required this.maxAttempts,
    required this.triggerNonce,
    required this.isRetryScheduled,
    required this.isExhausted,
    this.errorMessage,
  });

  factory PlayerReconnectState.initial({int maxAttempts = 5}) {
    return PlayerReconnectState(
      attemptsCompleted: 0,
      maxAttempts: maxAttempts,
      triggerNonce: 0,
      isRetryScheduled: false,
      isExhausted: false,
      errorMessage: null,
    );
  }

  final int attemptsCompleted;
  final int maxAttempts;
  final int triggerNonce;
  final bool isRetryScheduled;
  final bool isExhausted;
  final String? errorMessage;

  int get nextAttemptDisplay => (attemptsCompleted + 1).clamp(1, maxAttempts);

  PlayerReconnectState copyWith({
    int? attemptsCompleted,
    int? maxAttempts,
    int? triggerNonce,
    bool? isRetryScheduled,
    bool? isExhausted,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PlayerReconnectState(
      attemptsCompleted: attemptsCompleted ?? this.attemptsCompleted,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      triggerNonce: triggerNonce ?? this.triggerNonce,
      isRetryScheduled: isRetryScheduled ?? this.isRetryScheduled,
      isExhausted: isExhausted ?? this.isExhausted,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class PlayerReconnectController extends StateNotifier<PlayerReconnectState> {
  PlayerReconnectController({int maxAttempts = 5})
    : _random = Random(),
      super(PlayerReconnectState.initial(maxAttempts: maxAttempts));

  final Random _random;
  Timer? _reconnectTimer;

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void scheduleReconnect({required String message}) {
    if (state.isExhausted) {
      return;
    }

    if (_isDefinitiveError(message)) {
      _reconnectTimer?.cancel();
      state = state.copyWith(
        attemptsCompleted: state.maxAttempts,
        errorMessage: 'Este contenido no esta disponible por el momento.',
        isRetryScheduled: false,
        isExhausted: true,
      );
      return;
    }

    if (state.isRetryScheduled) {
      return;
    }

    if (state.attemptsCompleted >= state.maxAttempts) {
      if (state.isExhausted) {
        return;
      }
      state = state.copyWith(
        attemptsCompleted: state.maxAttempts,
        errorMessage: 'Este contenido no esta disponible por el momento.',
        isRetryScheduled: false,
        isExhausted: true,
      );
      return;
    }

    final baseSeconds = 2 * (1 << state.attemptsCompleted);
    final jitterMs = _random.nextInt(800);
    final backoff = Duration(
      seconds: baseSeconds.clamp(2, 20),
      milliseconds: jitterMs,
    );

    state = state.copyWith(
      errorMessage:
          '$message • reintento ${state.nextAttemptDisplay}/${state.maxAttempts}',
      isRetryScheduled: true,
      isExhausted: false,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoff, _emitReconnectTrigger);
  }

  void retryNow() {
    _reconnectTimer?.cancel();
    _emitReconnectTrigger();
  }

  void markPlaybackRecovered() {
    if ((state.attemptsCompleted <= 0 && !state.isExhausted) ||
        state.isRetryScheduled) {
      return;
    }
    state = state.copyWith(
      attemptsCompleted: 0,
      isExhausted: false,
      clearErrorMessage: true,
    );
  }

  void _emitReconnectTrigger() {
    state = state.copyWith(
      attemptsCompleted: state.attemptsCompleted + 1,
      triggerNonce: state.triggerNonce + 1,
      isRetryScheduled: false,
      isExhausted: false,
      clearErrorMessage: true,
    );
  }

  bool _isDefinitiveError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('403') ||
        lower.contains('404') ||
        lower.contains('forbidden') ||
        lower.contains('not found') ||
        lower.contains('failed to open') ||
        lower.contains('cannot open');
  }
}

final playerReconnectControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerReconnectController, PlayerReconnectState, String>((
      ref,
      key,
    ) {
      return PlayerReconnectController(maxAttempts: _maxAttemptsForKey(key));
    });

int _maxAttemptsForKey(String key) {
  final contentType = key.split(':').first.toLowerCase();
  if (contentType == 'live') {
    return 4;
  }
  return 5;
}
