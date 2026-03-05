import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/parental_provider.dart';
import '../providers/vod_provider.dart';
import '../widgets/stitch_content_card.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(vodCategoriesProvider);
    final streamsAsync = ref.watch(vodStreamsProvider);
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }

                _selectedCategoryId ??= categories.first.id;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category.id == _selectedCategoryId;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(category.name),
                      onSelected: (_) => setState(() => _selectedCategoryId = category.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error categorías VOD: $error')),
            ),
          ),
          Expanded(
            child: streamsAsync.when(
              data: (streams) {
                var filtered = _selectedCategoryId == null
                    ? streams
                    : streams.where((e) => e.categoryId == _selectedCategoryId).toList(growable: false);

                if (parental.enabled) {
                  filtered = filtered.where((e) => !_isAdultContent(e.name)).toList(growable: false);
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text('No hay películas en esta categoría.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return StitchContentCard(
                      title: item.name,
                      imageUrl: item.coverUrl,
                      onTap: () => context.push(
                        '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error películas: $error')),
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
}
