import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MediaKitPlayerView extends StatefulWidget {
  const MediaKitPlayerView({
    super.key,
    required this.url,
    required this.onProgress,
    required this.onError,
    this.initialPosition,
    this.onPlayerCreated,
  });

  final String url;
  final void Function(Duration position, Duration duration) onProgress;
  final void Function(String message) onError;
  final Duration? initialPosition;
  final void Function(Player player)? onPlayerCreated;

  @override
  State<MediaKitPlayerView> createState() => _MediaKitPlayerViewState();
}

class _MediaKitPlayerViewState extends State<MediaKitPlayerView> {
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<String>? _errorSub;
  Duration _lastDuration = Duration.zero;
  bool _seekApplied = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    widget.onPlayerCreated?.call(_player);

    _positionSub = _player.stream.position.listen((position) {
      widget.onProgress(position, _lastDuration);

      if (!_seekApplied && (widget.initialPosition ?? Duration.zero) > Duration.zero) {
        _seekApplied = true;
        _player.seek(widget.initialPosition!);
      }
    });

    _durationSub = _player.stream.duration.listen((duration) {
      _lastDuration = duration;
    });

    _errorSub = _player.stream.error.listen(widget.onError);

    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _videoController,
      controls: null,
      fit: BoxFit.contain,
      fill: const Color(0xFF000000),
    );
  }
}
