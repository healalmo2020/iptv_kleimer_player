import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/favorites_provider.dart';
import '../providers/library_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(favoritesItemsProvider);

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
        title: const Text('Favorites'),
      ),
      body: items.isEmpty
          ? const Center(child: Text('Aún no tienes favoritos.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final streamId = item['id']?.toString() ?? '';
                final title = item['name']?.toString() ?? 'Canal';

                return ListTile(
                  tileColor: const Color(0xFF162544),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(title),
                  subtitle: Text('Stream ID: $streamId'),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Color(0xFFFF5252)),
                    onPressed: () {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggleByPayload(streamId: streamId, payload: item);
                    },
                  ),
                  onTap: () => context.push(
                    '/player?title=${Uri.encodeComponent(title)}&id=$streamId',
                  ),
                );
              },
            ),
    );
  }
}
