import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';
import '../providers/live_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(liveStreamsProvider);
    final favorites = ref.watch(favoritesItemsProvider);
    final history = ref.watch(historyItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar en Live, Favoritos e Historial...',
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: liveAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error búsqueda: $error')),
              data: (live) {
                final merged = <_SearchItem>[];
                merged.addAll(
                  live.map(
                    (e) => _SearchItem(
                      id: e.id,
                      title: e.name,
                      type: 'live',
                      subtitle: 'Live TV',
                    ),
                  ),
                );

                merged.addAll(
                  favorites.map(
                    (e) => _SearchItem(
                      id: e['id']?.toString() ?? '',
                      title: e['name']?.toString() ?? 'Favorito',
                      type: 'favorite',
                      subtitle: 'Favorito',
                    ),
                  ),
                );

                merged.addAll(
                  history.map(
                    (e) => _SearchItem(
                      id: e['id']?.toString() ?? '',
                      title: e['title']?.toString() ?? 'Historial',
                      type: 'history',
                      subtitle: 'Historial',
                    ),
                  ),
                );

                final unique = <String, _SearchItem>{};
                for (final item in merged) {
                  if (item.id.isEmpty) {
                    continue;
                  }
                  unique[item.id] = item;
                }

                final filtered = unique.values
                    .where((e) => _query.isEmpty || e.title.toLowerCase().contains(_query))
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return const Center(child: Text('Sin resultados.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      tileColor: const Color(0xFF162544),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(_iconForType(item.type)),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () => context.push('/player?title=${Uri.encodeComponent(item.title)}&id=${item.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'favorite':
        return Icons.favorite;
      case 'history':
        return Icons.history;
      default:
        return Icons.live_tv;
    }
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.title,
    required this.type,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String type;
  final String subtitle;
}
