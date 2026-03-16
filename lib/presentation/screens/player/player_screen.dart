import 'dart:async';

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
import '../../../domain/entities/player_engine.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_playback_provider.dart';
import '../../providers/player_reconnect_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/player/media_kit_player_view.dart';
import '../../widgets/player/vlc_player_view.dart';
import '../../../core/constants/player_buffer_constants.dart';

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
  Timer? _saveTimer;
  Timer? _stallWatchdog;
  Timer? _continuousSeekTimer;
  Timer? _unavailableExitTimer;
  Player? _mediaKitPlayer;
  VlcPlayerController? _vlcController;
  final _floating = Floating();

  String get _reconnectProviderKey =>
      '${widget.contentType}:${widget.streamId}';

  String get _playbackProviderKey => '${widget.contentType}:${widget.streamId}';

  @override
  void initState() {
    super.initState();
    _startPersistenceLoop();
    _startStallWatchdog();
    unawaited(_saveHistoryEntry());
    unawaited(_enableAutoPiPOnLeave());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _stallWatchdog?.cancel();
    _continuousSeekTimer?.cancel();
    _unavailableExitTimer?.cancel();
    unawaited(_disableAutoPiPOnLeave());
    super.dispose();
  }

  void _startPersistenceLoop() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      unawaited(_persistProgress());
    });
  }

  void _startStallWatchdog() {
    _stallWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) {
        return;
      }
      final bufferProfile = ref.read(playerBufferProfileProvider);
      final bufferConfig = PlayerBufferConstants.configForProfile(bufferProfile);
      final reconnectState = ref.read(
        playerReconnectControllerProvider(_reconnectProviderKey),
      );
      if (reconnectState.isRetryScheduled) {
        return;
      }
      final playbackController = ref.read(
        playerPlaybackControllerProvider(_playbackProviderKey).notifier,
      );
      if (playbackController.shouldReconnect(
        bufferConfig.stallWatchdogThreshold,
      )) {
        _scheduleReconnect('Buffering estancado, reconectando...');
      }
    });
  }

  Future<void> _persistProgress() async {
    if (!mounted) {
      return;
    }
    await ref
        .read(playerPlaybackControllerProvider(_playbackProviderKey).notifier)
        .persistProgress(widget.streamId);
  }

  Future<void> _saveHistoryEntry() async {
    if (!mounted) {
      return;
    }
    await ref
        .read(playerPlaybackControllerProvider(_playbackProviderKey).notifier)
        .saveHistoryEntry(
          streamId: widget.streamId,
          title: widget.title,
          contentType: widget.contentType,
          extension: widget.extension,
        );
  }

  void _onProgress(Duration position, Duration duration) {
    if (!mounted) {
      return;
    }

    final playbackController = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey).notifier,
    );
    final previousMs = ref
        .read(playerPlaybackControllerProvider(_playbackProviderKey))
        .lastPositionMs;

    final shouldAutoplay = playbackController.onProgress(
      position: position,
      duration: duration,
      hasNextEpisode:
          widget.contentType == 'series' &&
          (widget.nextEpisodeId?.isNotEmpty ?? false),
    );

    if (playbackController.consumeProgressAdvancedSince(previousMs)) {
      ref
          .read(
            playerReconnectControllerProvider(_reconnectProviderKey).notifier,
          )
          .markPlaybackRecovered();
    }

    if (shouldAutoplay) {
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

  void _scheduleReconnect(String message) {
    if (!mounted) {
      return;
    }
    final reconnectMessage = _sanitizeReconnectMessage(message);
    ref
        .read(playerReconnectControllerProvider(_reconnectProviderKey).notifier)
        .scheduleReconnect(message: reconnectMessage);
  }

  String _sanitizeReconnectMessage(String message) {
    final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();
    final looksLikeOpenFailure =
        lower.contains('failed to open') ||
        lower.contains('cannot open');
    final containsRouteOrUrl =
        lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('/live/') ||
        lower.contains('/movie/') ||
        lower.contains('.m3u8') ||
        lower.contains('.ts');

    if (looksLikeOpenFailure || containsRouteOrUrl) {
      return 'Failed to open channel: ${widget.title}';
    }

    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEngine = ref.watch(playerEngineProvider);
    final bufferProfile = ref.watch(playerBufferProfileProvider);
    final bufferConfig = PlayerBufferConstants.configForProfile(bufferProfile);
    final canUseVlc =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
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
    final playbackState = ref.watch(
      playerPlaybackControllerProvider(_playbackProviderKey),
    );
    final playbackController = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey).notifier,
    );
    if (playbackState.activeUrlsCount != urls.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(
              playerPlaybackControllerProvider(_playbackProviderKey).notifier,
            )
            .setActiveUrlsCount(urls.length);
      });
    }

    final currentUrl = urls[playbackState.urlIndex % urls.length];

    final initialPosition = playbackController.getInitialPosition(
      widget.streamId,
    );
    final isLiveContent = widget.contentType == 'live';
    final canSeek =
        !isLiveContent && playbackState.currentDuration > Duration.zero;
    final totalMs = playbackState.currentDuration.inMilliseconds <= 0
        ? 1
        : playbackState.currentDuration.inMilliseconds;
    final currentSeekPosition = playbackController.seekBasePosition;
    final progressValue = isLiveContent
        ? 1.0
        : currentSeekPosition.inMilliseconds.clamp(0, totalMs) / totalMs;
    final hasNextEpisode =
        widget.contentType == 'series' &&
        (widget.nextEpisodeId?.isNotEmpty ?? false);
    final reconnectState = ref.watch(
      playerReconnectControllerProvider(_reconnectProviderKey),
    );

    ref.listen<PlayerReconnectState>(
      playerReconnectControllerProvider(_reconnectProviderKey),
      (previous, next) {
        if (!mounted) {
          return;
        }

        if ((previous?.triggerNonce ?? 0) == next.triggerNonce) {
          final becameExhausted =
              !(previous?.isExhausted ?? false) && next.isExhausted;
          if (becameExhausted) {
            _scheduleUnavailableExit();
          }
          if (!next.isExhausted) {
            _unavailableExitTimer?.cancel();
          }
          return;
        }

        _unavailableExitTimer?.cancel();
        playbackController.applyReconnectTrigger();
      },
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.25,
            colors: [Color(0xFF112525), Color(0xFF081212), Color(0xFF030707)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xFF03090D),
                          ),
                          child: engine == PlayerEngine.vlc
                              ? VlcPlayerView(
                                  key: ValueKey(
                                    'vlc-${widget.streamId}-${playbackState.playerInstanceNonce}-${bufferProfile.name}',
                                  ),
                                  url: currentUrl,
                                  bufferConfig: bufferConfig,
                                  initialPosition: initialPosition,
                                  onProgress: _onProgress,
                                  onError: (message) =>
                                      _scheduleReconnect(message),
                                  onControllerCreated: (controller) {
                                    _vlcController = controller;
                                    playbackController.setPlaying(true);
                                  },
                                )
                              : MediaKitPlayerView(
                                  key: ValueKey(
                                    'media-${widget.streamId}-${playbackState.playerInstanceNonce}-${bufferProfile.name}',
                                  ),
                                  url: currentUrl,
                                  bufferConfig: bufferConfig,
                                  initialPosition: initialPosition,
                                  onProgress: _onProgress,
                                  onError: (message) =>
                                      _scheduleReconnect(message),
                                  onPlayerCreated: (player) {
                                    _mediaKitPlayer = player;
                                    playbackController.setPlaying(true);
                                  },
                                ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x9903090D),
                                Colors.transparent,
                                Color(0xCC03090D),
                              ],
                              stops: [0, 0.42, 1],
                            ),
                          ),
                        ),
                        if (reconnectState.isRetryScheduled ||
                            reconnectState.isExhausted)
                          Positioned.fill(
                            child: Center(
                              child: _InlineReconnectStatus(
                                isExhausted: reconnectState.isExhausted,
                                message: reconnectState.errorMessage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                top: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FrostButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                          return;
                        }
                        context.go('/home');
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEAF9F9),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isLiveContent
                                      ? const Color(0x26FF4D4D)
                                      : const Color(0x220DF2F2),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isLiveContent
                                        ? const Color(0x59FF4D4D)
                                        : const Color(0x440DF2F2),
                                  ),
                                ),
                                child: Text(
                                  isLiveContent
                                      ? 'LIVE 4K'
                                      : widget.contentType.toUpperCase(),
                                  style: TextStyle(
                                    color: isLiveContent
                                        ? const Color(0xFFFFB8B8)
                                        : const Color(0xFF7DF6F6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x99102222),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0x220DF2F2),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wifi,
                                      size: 12,
                                      color: Color(0xFF0DF2F2),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Signal: Optimal',
                                      style: TextStyle(
                                        color: Color(0xFFBEECEC),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<PlayerEngine>(
                      initialValue: engine,
                      onSelected: (value) => ref
                          .read(playerEngineProvider.notifier)
                          .setEngine(value),
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
                      child: const _FrostButton(icon: Icons.tune),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xB3081212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x220DF2F2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isLiveContent
                                ? 'LIVE'
                                : _formatDuration(currentSeekPosition),
                            style: const TextStyle(
                              color: Color(0xFF0DF2F2),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isLiveContent
                                ? 'STREAM ACTIVE'
                                : _formatDuration(
                                    playbackState.currentDuration,
                                  ),
                            style: const TextStyle(
                              color: Color(0xFF8BA3A3),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: progressValue,
                          backgroundColor: const Color(0x1F0DF2F2),
                          color: const Color(0xFF0DF2F2),
                        ),
                      ),
                      if (!isLiveContent)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: const Color(0xFF0DF2F2),
                            inactiveTrackColor: const Color(0x220DF2F2),
                            thumbColor: Colors.white,
                            overlayColor: const Color(0x220DF2F2),
                          ),
                          child: Slider(
                            min: 0,
                            max: totalMs.toDouble(),
                            value: currentSeekPosition.inMilliseconds
                                .clamp(0, totalMs)
                                .toDouble(),
                            onChanged:
                                playbackState.currentDuration <= Duration.zero
                                ? null
                                : (value) {
                                    playbackController.beginSeek(
                                      Duration(milliseconds: value.round()),
                                    );
                                  },
                            onChangeEnd:
                                playbackState.currentDuration <= Duration.zero
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
                        ),
                      const SizedBox(height: 2),
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
                            child: _ControlIconButton(
                              icon: Icons.replay_10_rounded,
                              onTap: canSeek
                                  ? () => unawaited(
                                      _seekBy(
                                        engine,
                                        const Duration(seconds: -10),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => unawaited(_togglePlayPause(engine)),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0DF2F2),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x660DF2F2),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                playbackState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: const Color(0xFF081212),
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onLongPressStart: canSeek
                                ? (_) => _startContinuousSeek(
                                    engine,
                                    const Duration(seconds: 10),
                                  )
                                : null,
                            onLongPressEnd: (_) => _stopContinuousSeek(),
                            onLongPressCancel: _stopContinuousSeek,
                            child: _ControlIconButton(
                              icon: Icons.forward_10_rounded,
                              onTap: canSeek
                                  ? () => unawaited(
                                      _seekBy(
                                        engine,
                                        const Duration(seconds: 10),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PlayerAction(
                            icon: Icons.closed_caption_rounded,
                            label: 'Subtitles',
                            onTap: () => _openSubtitleSelector(engine),
                          ),
                          _PlayerAction(
                            icon: Icons.graphic_eq_rounded,
                            label: 'Audio',
                            onTap: () => _openAudioSelector(engine),
                          ),
                          _PlayerAction(
                            icon: Icons.picture_in_picture_alt_outlined,
                            label: 'PiP',
                            onTap: _enterPiP,
                          ),
                          const _PlayerAction(
                            icon: Icons.high_quality_rounded,
                            label: 'Auto 4K',
                          ),
                          _PlayerAction(
                            icon: Icons.fullscreen_rounded,
                            label: 'Fullscreen',
                            onTap: () => _showHint(
                              'Pantalla completa no implementada aun.',
                            ),
                          ),
                          if (hasNextEpisode)
                            _PlayerAction(
                              icon: Icons.skip_next_rounded,
                              label: 'Next Episode',
                              onTap: () {
                                final nextId = widget.nextEpisodeId;
                                if (nextId == null) {
                                  return;
                                }
                                final nextTitle =
                                    widget.nextEpisodeTitle ??
                                    'Siguiente episodio';
                                final nextExt =
                                    widget.nextEpisodeExtension ?? '';
                                context.go(
                                  '/player?title=${Uri.encodeComponent(nextTitle)}&id=$nextId&type=series&ext=$nextExt',
                                );
                              },
                            ),
                        ],
                      ),
                      if (reconnectState.isExhausted) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFFFD9B3),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: const Text(
                                'Este contenido no esta disponible. Regresando...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFFFFD9B3),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final playbackController = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey).notifier,
    );
    final playbackState = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey),
    );

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
      playbackController.setPlaying(player.state.playing);
      return;
    }

    final controller = _vlcController;
    if (controller == null) {
      _showHint('Reproductor no está listo todavía.');
      return;
    }

    if (playbackState.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) {
      return;
    }
    playbackController.setPlaying(!playbackState.isPlaying);
  }

  Future<void> _seekTo(PlayerEngine engine, Duration position) async {
    final playbackController = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey).notifier,
    );
    final clamped = playbackController.clampToDuration(position);

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
    playbackController.completeSeek(clamped);
  }

  Future<void> _seekBy(PlayerEngine engine, Duration delta) async {
    final playbackState = ref.read(
      playerPlaybackControllerProvider(_playbackProviderKey),
    );
    if (playbackState.currentDuration <= Duration.zero) {
      return;
    }

    unawaited(HapticFeedback.lightImpact());

    final base = playbackState.isSeeking
        ? playbackState.dragPosition
        : playbackState.currentPosition;
    final target = base + delta;
    await _seekTo(engine, target);
  }

  void _startContinuousSeek(PlayerEngine engine, Duration delta) {
    _continuousSeekTimer?.cancel();
    unawaited(_seekBy(engine, delta));
    _continuousSeekTimer = Timer.periodic(const Duration(milliseconds: 280), (
      _,
    ) {
      if (!mounted) {
        _stopContinuousSeek();
        return;
      }
      unawaited(_seekBy(engine, delta));
    });
  }

  void _stopContinuousSeek() {
    _continuousSeekTimer?.cancel();
    _continuousSeekTimer = null;
  }

  void _scheduleUnavailableExit() {
    _unavailableExitTimer?.cancel();
    _unavailableExitTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      context.go(_contentFallbackRoute);
    });
  }

  String get _contentFallbackRoute => switch (widget.contentType) {
    'live' => '/live',
    'vod' => '/movies',
    'series' => '/series',
    _ => '/home',
  };
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x99102222),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x220DF2F2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF97B1B1)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCCEEEE),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xAA102222),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x220DF2F2)),
        ),
        child: Icon(icon, color: const Color(0xFFEAF9F9)),
      ),
    );
  }
}

class _FrostButton extends StatelessWidget {
  const _FrostButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x99102222),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x220DF2F2)),
        ),
        child: Icon(icon, color: const Color(0xFFEAF9F9)),
      ),
    );
  }
}

class _InlineReconnectStatus extends StatelessWidget {
  const _InlineReconnectStatus({required this.isExhausted, this.message});

  final bool isExhausted;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: isExhausted
                ? const Icon(
                    Icons.info_outline_rounded,
                    size: 28,
                    color: Color(0xFFFFD9B3),
                  )
                : const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0DF2F2)),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            isExhausted
                ? 'Contenido no disponible. Regresando...'
                : (message ?? 'Reconectando...'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isExhausted
                  ? const Color(0xFFFFD9B3)
                  : const Color(0xFFE6F9F9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
