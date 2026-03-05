import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/local_storage_service.dart';
import '../../providers/settings_provider.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamId,
  });

  final String title;
  final String streamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playerEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF162544),
              ),
              child: Center(
                child: Text(
                  'Player activo: ${engine == PlayerEngine.vlc ? 'VLC' : 'Media Kit'}\nStream ID: $streamId',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PlayerAction(icon: Icons.closed_caption, label: 'Subtítulos'),
                _PlayerAction(icon: Icons.graphic_eq, label: 'Audio'),
                _PlayerAction(icon: Icons.high_quality, label: 'Calidad'),
                _PlayerAction(icon: Icons.fullscreen, label: 'Fullscreen'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAction extends StatelessWidget {
  const _PlayerAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Icon(icon), const SizedBox(height: 6), Text(label)],
    );
  }
}
