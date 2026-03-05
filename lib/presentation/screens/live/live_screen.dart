import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/live_provider.dart';
import '../../providers/parental_provider.dart';
import '../../widgets/stitch_content_card.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(liveCategoriesProvider);
    final streams = ref.watch(liveStreamsProvider);
    final favorites = ref.watch(favoritesProvider);
    final parental = ref.watch(parentalProvider);

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
              data: (items) {
                final filteredItems = parental.enabled
                    ? items.where((e) => !_isAdultContent(e.name)).toList(growable: false)
                    : items;

                return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 16 / 9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final stream = filteredItems[index];
                  final isFavorite = favorites.contains(stream.id);
                  return StitchContentCard(
                    title: stream.name,
                    imageUrl: stream.iconUrl,
                      onTap: () => context.push('/player?title=${Uri.encodeComponent(stream.name)}&id=${stream.id}&type=live'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.schedule),
                            color: Colors.white,
                            onPressed: () => _showEpg(context, ref, stream.id, stream.name),
                          ),
                          IconButton(
                            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                            color: isFavorite ? const Color(0xFFFF5252) : Colors.white,
                            onPressed: () => ref.read(favoritesProvider.notifier).toggle(stream),
                          ),
                        ],
                    ),
                  );
                },
              );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error streams: $error')),
            ),
          ),
        ],
      ),
    );
  }

  bool _isAdultContent(String title) {
    final value = title.toLowerCase();
    return value.contains('adult') || value.contains('xxx') || value.contains('+18');
  }

  Future<void> _showEpg(
    BuildContext context,
    WidgetRef ref,
    String streamId,
    String streamName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final epgAsync = ref.watch(liveEpgProvider(streamId));
        return SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('EPG • $streamName', style: Theme.of(context).textTheme.titleMedium),
              ),
              Expanded(
                child: epgAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error EPG: $error')),
                  data: (events) {
                    if (events.isEmpty) {
                      return const Center(child: Text('No hay programación disponible.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final start = event.start == null
                            ? '--:--'
                            : '${event.start!.hour.toString().padLeft(2, '0')}:${event.start!.minute.toString().padLeft(2, '0')}';
                        final end = event.end == null
                            ? '--:--'
                            : '${event.end!.hour.toString().padLeft(2, '0')}:${event.end!.minute.toString().padLeft(2, '0')}';

                        return ListTile(
                          tileColor: const Color(0xFF162544),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          title: Text(event.title),
                          subtitle: Text('$start - $end\n${event.description}'),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
