import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class VlcPlayerView extends StatefulWidget {
  const VlcPlayerView({
    super.key,
    required this.url,
    required this.onProgress,
    required this.onError,
    this.initialPosition,
  });

  final String url;
  final void Function(Duration position, Duration duration) onProgress;
  final void Function(String message) onError;
  final Duration? initialPosition;

  @override
  State<VlcPlayerView> createState() => _VlcPlayerViewState();
}

class _VlcPlayerViewState extends State<VlcPlayerView> {
  late final VlcPlayerController _controller;
  bool _errorNotified = false;
  bool _seekApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.url,
      autoPlay: true,
      hwAcc: HwAcc.auto,
      options: VlcPlayerOptions(),
    );

    _controller.addListener(() {
      final value = _controller.value;
      widget.onProgress(value.position, value.duration);

      if (!_seekApplied && value.isInitialized && (widget.initialPosition ?? Duration.zero) > Duration.zero) {
        _seekApplied = true;
        _controller.seekTo(widget.initialPosition!);
      }

      if (!_errorNotified && value.hasError) {
        _errorNotified = true;
        widget.onError(value.errorDescription);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VlcPlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
      placeholder: const Center(child: CircularProgressIndicator()),
    );
  }
}
