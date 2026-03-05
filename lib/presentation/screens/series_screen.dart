import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/parental_provider.dart';
import '../providers/series_provider.dart';
import '../widgets/stitch_content_card.dart';

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(seriesProvider);
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Series')),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error series: $error')),
        data: (items) {
          final filtered = parental.enabled
              ? items.where((e) => !_isAdultContent(e.name)).toList(growable: false)
              : items;

          if (filtered.isEmpty) {
            return const Center(child: Text('No hay series disponibles.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2 / 3,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return StitchContentCard(
                title: item.name,
                imageUrl: item.coverUrl,
                aspectRatio: 2 / 3,
                onTap: () => context.push(
                  '/series/details?id=${item.id}&title=${Uri.encodeComponent(item.name)}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isAdultContent(String title) {
    final value = title.toLowerCase();
    return value.contains('adult') || value.contains('xxx') || value.contains('+18');
  }
}
