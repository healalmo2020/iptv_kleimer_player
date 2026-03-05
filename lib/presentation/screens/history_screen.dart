import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: items.isEmpty
          ? const Center(child: Text('No hay historial todavía.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final streamId = item['id']?.toString() ?? '';
                final title = item['title']?.toString() ?? 'Contenido';
                final updatedAt = item['updatedAt']?.toString() ?? '';
                final type = item['type']?.toString() ?? 'live';
                final ext = item['ext']?.toString() ?? '';
                return ListTile(
                  tileColor: const Color(0xFF162544),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(title),
                  subtitle: Text(updatedAt),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => context.push('/player?title=${Uri.encodeComponent(title)}&id=$streamId&type=$type&ext=$ext'),
                );
              },
            ),
    );
  }
}
