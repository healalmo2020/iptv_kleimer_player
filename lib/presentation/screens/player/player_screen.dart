import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  int _playerInstanceNonce = 0;
  int _urlIndex = 0;
  int _reconnectAttempts = 0;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  String? _lastError;
  Timer? _saveTimer;
  Timer? _reconnectTimer;
  bool _autoplayTriggered = false;
  Player? _mediaKitPlayer;

  @override
  void initState() {
    super.initState();
    _startPersistenceLoop();
    unawaited(_saveHistoryEntry());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _reconnectTimer?.cancel();
    unawaited(_persistProgress());
    super.dispose();
  }

  void _startPersistenceLoop() {
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    if (_currentDuration <= Duration.zero) {
      return;
    }

    await ref.read(localStorageProvider).savePlaybackProgress(
          widget.streamId,
          _currentPosition,
          _currentDuration,
        );
  }

  Future<void> _saveHistoryEntry() async {
    final storage = ref.read(localStorageProvider);
    await storage.saveLastChannel(widget.streamId);
    await storage.saveHistoryItem({
      'id': widget.streamId,
      'title': widget.title,
      'updatedAt': DateTime.now().toIso8601String(),
      'type': widget.contentType,
      'ext': widget.extension,
    });
  }

  void _onProgress(Duration position, Duration duration) {
    _currentPosition = position;
    _currentDuration = duration;

    final hasNextEpisode = widget.contentType == 'series' &&
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
          _lastError = message;
        });
      }
      return;
    }

    final backoff = Duration(seconds: 2 + (_reconnectAttempts * 2));
    _reconnectTimer?.cancel();
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
    final engine = ref.watch(playerEngineProvider);
    final auth = ref.watch(authControllerProvider);
    final session = auth.valueOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
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

    final savedProgress = ref.read(localStorageProvider).getPlaybackProgress(widget.streamId);
    final initialPosition = Duration(milliseconds: savedProgress?['positionMs'] as int? ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<PlayerEngine>(
            initialValue: engine,
            onSelected: (value) => ref.read(playerEngineProvider.notifier).setEngine(value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: PlayerEngine.vlc, child: Text('VLC Player')),
              PopupMenuItem(value: PlayerEngine.mediaKit, child: Text('Media Kit')),
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
                          key: ValueKey('vlc-${widget.streamId}-$_playerInstanceNonce'),
                          url: currentUrl,
                          initialPosition: initialPosition,
                          onProgress: _onProgress,
                          onError: (message) => _scheduleReconnect(message, urls.length),
                        )
                      : MediaKitPlayerView(
                          key: ValueKey('media-${widget.streamId}-$_playerInstanceNonce'),
                          url: currentUrl,
                          initialPosition: initialPosition,
                          onProgress: _onProgress,
                          onError: (message) => _scheduleReconnect(message, urls.length),
                          onPlayerCreated: (player) => _mediaKitPlayer = player,
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _currentDuration.inMilliseconds <= 0
                      ? 0
                      : _currentPosition.inMilliseconds / _currentDuration.inMilliseconds,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Posición: ${_formatDuration(_currentPosition)}'),
                    Text('Duración: ${_formatDuration(_currentDuration)}'),
                  ],
                ),
                if (_lastError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reintentando stream... $_lastError',
                    style: const TextStyle(color: Color(0xFFFF5252)),
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
                const _PlayerAction(icon: Icons.high_quality, label: 'Auto'),
                const _PlayerAction(icon: Icons.fullscreen, label: 'Fullscreen'),
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
          final label = track.title?.isNotEmpty == true ? track.title! : 'Audio ${index + 1}';
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
            final label = track.title?.isNotEmpty == true ? track.title! : 'Subtítulo ${index + 1}';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
