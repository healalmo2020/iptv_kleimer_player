import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_storage_service.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playerEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reproductor preferido', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioListTile<PlayerEngine>(
            value: PlayerEngine.vlc,
            groupValue: engine,
            title: const Text('VLC Player'),
            onChanged: (value) {
              if (value != null) {
                ref.read(playerEngineProvider.notifier).setEngine(value);
              }
            },
          ),
          RadioListTile<PlayerEngine>(
            value: PlayerEngine.mediaKit,
            groupValue: engine,
            title: const Text('Media Kit'),
            onChanged: (value) {
              if (value != null) {
                ref.read(playerEngineProvider.notifier).setEngine(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
