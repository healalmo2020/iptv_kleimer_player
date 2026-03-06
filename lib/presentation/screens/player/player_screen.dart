import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floating/floating.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/xtream_stream_url_builder.dart';
import '../../../services/local_storage_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/player/media_kit_player_view.dart';
import '../../widgets/player/vlc_player_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamId,
    this.contentType = 'live',
    this.extension,
    this.nextEpisodeId,
    this.nextEpisodeTitle,
    this.nextEpisodeExtension,
  });

  final String title;
  final String streamId;
  final String contentType;
  final String? extension;
  final String? nextEpisodeId;
  final String? nextEpisodeTitle;
  final String? nextEpisodeExtension;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _maxReconnectAttempts = 5;
  static const _stalledThreshold = Duration(seconds: 20);

  int _playerInstanceNonce = 0;
  int _urlIndex = 0;
  int _reconnectAttempts = 0;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  String? _lastError;
  Timer? _saveTimer;
  Timer? _reconnectTimer;
  Timer? _stallWatchdog;
  Timer? _continuousSeekTimer;
  bool _autoplayTriggered = false;
  Player? _mediaKitPlayer;
  VlcPlayerController? _vlcController;
  bool _isPlaying = true;
  bool _isSeeking = false;
  Duration _dragPosition = Duration.zero;
  final _floating = Floating();
  final _random = Random();
  late final LocalStorageService _storage;
  DateTime _lastProgressAt = DateTime.now();
  int _lastPositionMs = 0;
  int _activeUrlsCount = 2;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(localStorageProvider);
    _startPersistenceLoop();
    _startStallWatchdog();
    unawaited(_saveHistoryEntry());
    unawaited(_enableAutoPiPOnLeave());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallWatchdog?.cancel();
    _continuousSeekTimer?.cancel();
    unawaited(_disableAutoPiPOnLeave());
    unawaited(_persistProgress());
    super.dispose();
  }

  void _startPersistenceLoop() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_persistProgress());
    });
  }

  void _startStallWatchdog() {
    _stallWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _currentDuration <= Duration.zero) {
        return;
      }
      if (_reconnectTimer?.isActive ?? false) {
        return;
      }
      final elapsed = DateTime.now().difference(_lastProgressAt);
      if (elapsed >= _stalledThreshold) {
        _scheduleReconnect(
          'Buffering estancado, reconectando...',
          _activeUrlsCount,
        );
      }
    });
  }

  Future<void> _persistProgress() async {
    if (_currentDuration <= Duration.zero) {
      return;
    }

    await _storage.savePlaybackProgress(
      widget.streamId,
      _currentPosition,
      _currentDuration,
    );
  }

  Future<void> _saveHistoryEntry() async {
    await _storage.saveLastChannel(widget.streamId);
    await _storage.saveHistoryItem({
      'id': widget.streamId,
      'title': widget.title,
      'updatedAt': DateTime.now().toIso8601String(),
      'type': widget.contentType,
      'ext': widget.extension,
    });
  }

  void _onProgress(Duration position, Duration duration) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (!_isSeeking) {
        _currentPosition = position;
      }
      _currentDuration = duration;
    });

    final currentMs = position.inMilliseconds;
    if (currentMs > _lastPositionMs) {
      _lastPositionMs = currentMs;
      _lastProgressAt = DateTime.now();
    }

    final hasNextEpisode =
        widget.contentType == 'series' &&
        (widget.nextEpisodeId?.isNotEmpty ?? false) &&
        !_autoplayTriggered;

    if (!hasNextEpisode) {
      return;
    }

    if (_currentDuration > const Duration(seconds: 1) &&
        _currentPosition >= _currentDuration - const Duration(seconds: 2)) {
      _autoplayTriggered = true;
      final nextTitle = widget.nextEpisodeTitle ?? 'Siguiente episodio';
      final nextExt = widget.nextEpisodeExtension ?? '';
      final nextId = widget.nextEpisodeId!;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) {
          return;
        }
        context.go(
          '/player?title=${Uri.encodeComponent(nextTitle)}&id=$nextId&type=series&ext=$nextExt',
        );
      });
    }
  }

  void _scheduleReconnect(String message, int urlsCount) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (mounted) {
        setState(() {
          _lastError = '$message (límite de reintentos alcanzado)';
        });
      }
      return;
    }

    final baseSeconds = 2 * (1 << _reconnectAttempts);
    final jitterMs = _random.nextInt(800);
    final backoff = Duration(
      seconds: baseSeconds.clamp(2, 20),
      milliseconds: jitterMs,
    );
    _reconnectTimer?.cancel();
    if (mounted) {
      setState(() {
        _lastError =
            '$message • reintento ${_reconnectAttempts + 1}/$_maxReconnectAttempts';
      });
    }
    _reconnectTimer = Timer(backoff, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _reconnectAttempts += 1;
        _urlIndex = (_urlIndex + 1) % urlsCount;
        _playerInstanceNonce += 1;
        _lastError = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedEngine = ref.watch(playerEngineProvider);
    final canUseVlc = !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;
    final engine = canUseVlc ? selectedEngine : PlayerEngine.mediaKit;
    final auth = ref.watch(authControllerProvider);
    final session = auth.valueOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/home');
            },
          ),
          title: Text(widget.title),
        ),
        body: const Center(
          child: Text('No hay sesión activa. Vuelve a iniciar sesión.'),
        ),
      );
    }

    final urls = switch (widget.contentType) {
      'vod' => XtreamStreamUrlBuilder.vodUrls(
        baseUrl: AppConstants.baseUrl,
        username: session.username,
        password: session.password,
        streamId: widget.streamId,
        extension: widget.extension,
      ),
      'series' => XtreamStreamUrlBuilder.seriesEpisodeUrls(
        baseUrl: AppConstants.baseUrl,
        username: session.username,
        password: session.password,
        episodeId: widget.streamId,
        extension: widget.extension,
      ),
      _ => XtreamStreamUrlBuilder.liveUrls(
        baseUrl: AppConstants.baseUrl,
        username: session.username,
        password: session.password,
        streamId: widget.streamId,
      ),
    };
    final currentUrl = urls[_urlIndex % urls.length];
    _activeUrlsCount = urls.length;

    final savedProgress = _storage.getPlaybackProgress(widget.streamId);
    final initialPosition = Duration(
      milliseconds: savedProgress?['positionMs'] as int? ?? 0,
    );
    final isLiveContent = widget.contentType == 'live';
    final canSeek = !isLiveContent && _currentDuration > Duration.zero;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/home');
          },
        ),
        title: Text(widget.title),
        actions: [
          PopupMenuButton<PlayerEngine>(
            initialValue: engine,
            onSelected: (value) =>
                ref.read(playerEngineProvider.notifier).setEngine(value),
            itemBuilder: (_) => [
              if (canUseVlc)
                const PopupMenuItem(
                  value: PlayerEngine.vlc,
                  child: Text('VLC Player'),
                ),
              const PopupMenuItem(
                value: PlayerEngine.mediaKit,
                child: Text('Media Kit'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF162544),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: engine == PlayerEngine.vlc
                      ? VlcPlayerView(
                          key: ValueKey(
                            'vlc-${widget.streamId}-$_playerInstanceNonce',
                          ),
                          url: currentUrl,
                          initialPosition: initialPosition,
                          onProgress: _onProgress,
                          onError: (message) =>
                              _scheduleReconnect(message, urls.length),
                          onControllerCreated: (controller) {
                            _vlcController = controller;
                            _isPlaying = true;
                          },
                        )
                      : MediaKitPlayerView(
                          key: ValueKey(
                            'media-${widget.streamId}-$_playerInstanceNonce',
                          ),
                          url: currentUrl,
                          initialPosition: initialPosition,
                          onProgress: _onProgress,
                          onError: (message) =>
                              _scheduleReconnect(message, urls.length),
                          onPlayerCreated: (player) {
                            _mediaKitPlayer = player;
                            _isPlaying = true;
                          },
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                if (isLiveContent)
                  Row(
                    children: [
                      const Expanded(child: LinearProgressIndicator(value: 1)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Slider(
                    min: 0,
                    max:
                        (_currentDuration.inMilliseconds <= 0
                                ? 1
                                : _currentDuration.inMilliseconds)
                            .toDouble(),
                    value: (_isSeeking ? _dragPosition : _currentPosition)
                        .inMilliseconds
                        .clamp(
                          0,
                          _currentDuration.inMilliseconds <= 0
                              ? 1
                              : _currentDuration.inMilliseconds,
                        )
                        .toDouble(),
                    onChanged: _currentDuration <= Duration.zero
                        ? null
                        : (value) {
                            setState(() {
                              _isSeeking = true;
                              _dragPosition = Duration(
                                milliseconds: value.round(),
                              );
                            });
                          },
                    onChangeEnd: _currentDuration <= Duration.zero
                        ? null
                        : (value) {
                            unawaited(
                              _seekTo(
                                engine,
                                Duration(milliseconds: value.round()),
                              ),
                            );
                          },
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isLiveContent)
                      const Text('En vivo')
                    else
                      Text(
                        _formatDuration(
                          _isSeeking ? _dragPosition : _currentPosition,
                        ),
                      ),
                    if (isLiveContent)
                      const Text('')
                    else
                      Text(_formatDuration(_currentDuration)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onLongPressStart: canSeek
                          ? (_) => _startContinuousSeek(
                              engine,
                              const Duration(seconds: -10),
                            )
                          : null,
                      onLongPressEnd: (_) => _stopContinuousSeek(),
                      onLongPressCancel: _stopContinuousSeek,
                      child: IconButton(
                        iconSize: 30,
                        onPressed: canSeek
                            ? () => unawaited(
                                _seekBy(engine, const Duration(seconds: -10)),
                              )
                            : null,
                        icon: const Icon(Icons.replay_10),
                      ),
                    ),
                    IconButton(
                      iconSize: 38,
                      onPressed: () => unawaited(_togglePlayPause(engine)),
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      ),
                    ),
                    GestureDetector(
                      onLongPressStart: canSeek
                          ? (_) => _startContinuousSeek(
                              engine,
                              const Duration(seconds: 10),
                            )
                          : null,
                      onLongPressEnd: (_) => _stopContinuousSeek(),
                      onLongPressCancel: _stopContinuousSeek,
                      child: IconButton(
                        iconSize: 30,
                        onPressed: canSeek
                            ? () => unawaited(
                                _seekBy(engine, const Duration(seconds: 10)),
                              )
                            : null,
                        icon: const Icon(Icons.forward_10),
                      ),
                    ),
                  ],
                ),
                if (_lastError != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: const TextStyle(color: Color(0xFFFF5252)),
                        ),
                      ),
                      TextButton(
                        onPressed: _retryNow,
                        child: const Text('Reintentar ahora'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PlayerAction(
                  icon: Icons.closed_caption,
                  label: 'Subtítulos',
                  onTap: () => _openSubtitleSelector(engine),
                ),
                _PlayerAction(
                  icon: Icons.graphic_eq,
                  label: 'Audio',
                  onTap: () => _openAudioSelector(engine),
                ),
                _PlayerAction(
                  icon: Icons.picture_in_picture_alt_outlined,
                  label: 'PiP',
                  onTap: _enterPiP,
                ),
                const _PlayerAction(icon: Icons.high_quality, label: 'Auto'),
                const _PlayerAction(
                  icon: Icons.fullscreen,
                  label: 'Fullscreen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    if (value <= Duration.zero) {
      return '00:00';
    }

    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _openAudioSelector(PlayerEngine engine) async {
    if (engine != PlayerEngine.mediaKit || _mediaKitPlayer == null) {
      _showHint('Selección de audio disponible en modo Media Kit.');
      return;
    }

    final tracks = _mediaKitPlayer!.state.tracks.audio;
    if (tracks.isEmpty || !mounted) {
      _showHint('No hay pistas de audio disponibles.');
      return;
    }

    final selected = await showModalBottomSheet<AudioTrack>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final label = track.title?.isNotEmpty == true
              ? track.title!
              : 'Audio ${index + 1}';
          return ListTile(
            title: Text(label),
            subtitle: Text(track.language ?? ''),
            onTap: () => Navigator.of(context).pop(track),
          );
        },
      ),
    );

    if (selected != null) {
      await _mediaKitPlayer!.setAudioTrack(selected);
    }
  }

  Future<void> _openSubtitleSelector(PlayerEngine engine) async {
    if (engine != PlayerEngine.mediaKit || _mediaKitPlayer == null) {
      _showHint('Selección de subtítulos disponible en modo Media Kit.');
      return;
    }

    final tracks = _mediaKitPlayer!.state.tracks.subtitle;
    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<SubtitleTrack>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: [
          ListTile(
            title: const Text('Desactivar subtítulos'),
            onTap: () => Navigator.of(context).pop(SubtitleTrack.no()),
          ),
          ...List.generate(tracks.length, (index) {
            final track = tracks[index];
            final label = track.title?.isNotEmpty == true
                ? track.title!
                : 'Subtítulo ${index + 1}';
            return ListTile(
              title: Text(label),
              subtitle: Text(track.language ?? ''),
              onTap: () => Navigator.of(context).pop(track),
            );
          }),
        ],
      ),
    );

    if (selected != null) {
      await _mediaKitPlayer!.setSubtitleTrack(selected);
    }
  }

  void _showHint(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enableAutoPiPOnLeave() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final available = await _floating.isPipAvailable;
      if (!available) {
        return;
      }
      await _floating.enable(
        const OnLeavePiP(aspectRatio: Rational.landscape()),
      );
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _disableAutoPiPOnLeave() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _floating.cancelOnLeavePiP();
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _enterPiP() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _showHint('PiP disponible solo en Android.');
      return;
    }

    final available = await _floating.isPipAvailable;
    if (!available) {
      _showHint('PiP no está disponible en este dispositivo.');
      return;
    }

    await _floating.enable(
      const ImmediatePiP(aspectRatio: Rational.landscape()),
    );
  }

  Future<void> _togglePlayPause(PlayerEngine engine) async {
    if (engine == PlayerEngine.mediaKit) {
      final player = _mediaKitPlayer;
      if (player == null) {
        _showHint('Reproductor no está listo todavía.');
        return;
      }

      if (player.state.playing) {
        await player.pause();
      } else {
        await player.play();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = player.state.playing;
      });
      return;
    }

    final controller = _vlcController;
    if (controller == null) {
      _showHint('Reproductor no está listo todavía.');
      return;
    }

    if (_isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _seekTo(PlayerEngine engine, Duration position) async {
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        _currentDuration.inMilliseconds,
      ),
    );

    if (engine == PlayerEngine.mediaKit) {
      final player = _mediaKitPlayer;
      if (player == null) {
        return;
      }
      await player.seek(clamped);
    } else {
      final controller = _vlcController;
      if (controller == null) {
        return;
      }
      await controller.seekTo(clamped);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSeeking = false;
      _currentPosition = clamped;
    });
  }

  Future<void> _seekBy(PlayerEngine engine, Duration delta) async {
    if (_currentDuration <= Duration.zero) {
      return;
    }

    final base = _isSeeking ? _dragPosition : _currentPosition;
    final target = base + delta;
    await _seekTo(engine, target);
  }

  void _startContinuousSeek(PlayerEngine engine, Duration delta) {
    _continuousSeekTimer?.cancel();
    unawaited(_seekBy(engine, delta));
    _continuousSeekTimer = Timer.periodic(const Duration(milliseconds: 280), (
      _,
    ) {
      unawaited(_seekBy(engine, delta));
    });
  }

  void _stopContinuousSeek() {
    _continuousSeekTimer?.cancel();
    _continuousSeekTimer = null;
  }

  void _retryNow() {
    if (!mounted) {
      return;
    }
    _reconnectTimer?.cancel();
    setState(() {
      _urlIndex = (_urlIndex + 1) % _activeUrlsCount;
      _playerInstanceNonce += 1;
      _lastError = null;
      _lastProgressAt = DateTime.now();
      _isPlaying = true;
      _isSeeking = false;
    });
  }
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [Icon(icon), const SizedBox(height: 6), Text(label)],
        ),
      ),
    );
  }
}
