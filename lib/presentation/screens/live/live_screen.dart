import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/live_provider.dart';
import '../../widgets/stitch_content_card.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(liveCategoriesProvider);
    final streams = ref.watch(liveStreamsProvider);
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live TV')),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: categories.when(
              data: (data) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: data.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Chip(label: Text(data[index].name)),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error categorías: $error')),
            ),
          ),
          Expanded(
            child: streams.when(
              data: (items) => GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 16 / 9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final stream = items[index];
                  final isFavorite = favorites.contains(stream.id);
                  return StitchContentCard(
                    title: stream.name,
                    imageUrl: stream.iconUrl,
                    onTap: () => context.push('/player?title=${Uri.encodeComponent(stream.name)}&id=${stream.id}'),
                    trailing: IconButton(
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                      color: isFavorite ? const Color(0xFFFF5252) : Colors.white,
                      onPressed: () => ref.read(favoritesProvider.notifier).toggle(stream),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error streams: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
