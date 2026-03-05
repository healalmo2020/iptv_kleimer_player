import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/live_provider.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(liveCategoriesProvider);
    final streams = ref.watch(liveStreamsProvider);

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
                  return InkWell(
                    onTap: () => context.push('/player?title=${Uri.encodeComponent(stream.name)}&id=${stream.id}'),
                    child: Card(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (stream.iconUrl != null && stream.iconUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: stream.iconUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.tv),
                            )
                          else
                            const ColoredBox(color: Color(0xFF162544)),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black54,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                stream.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
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
