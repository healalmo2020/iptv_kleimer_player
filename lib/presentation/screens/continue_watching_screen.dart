import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';

class ContinueWatchingScreen extends ConsumerWidget {
  const ContinueWatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(continueWatchingProvider);

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
        title: const Text('Continue Watching'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No hay contenido para reanudar.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 9,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final streamId = item['id']?.toString() ?? '';
                final title = item['title']?.toString() ?? 'Contenido';
                final type = item['type']?.toString() ?? 'live';
                final ext = item['ext']?.toString() ?? '';
                final positionMs = (item['positionMs'] as int?) ?? 0;
                final durationMs = (item['durationMs'] as int?) ?? 1;
                final progress = (positionMs / durationMs).clamp(0.0, 1.0);

                return InkWell(
                  onTap: () => context.push(
                    '/player?title=${Uri.encodeComponent(title)}&id=$streamId&type=$type&ext=$ext',
                  ),
                  child: Card(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF162544)),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: LinearProgressIndicator(value: progress),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
