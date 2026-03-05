import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';
import '../providers/live_provider.dart';
import '../providers/series_provider.dart';
import '../providers/vod_provider.dart';
import '../widgets/stitch_content_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching = ref.watch(continueWatchingProvider);
    final favorites = ref.watch(favoritesItemsProvider);
    final liveAsync = ref.watch(liveStreamsProvider);
    final vodAsync = ref.watch(vodStreamsProvider);
    final seriesAsync = ref.watch(seriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('IPTV Kleimer Player')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: MediaQuery.sizeOf(context).height * 0.7,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF162544), Color(0xFF0B1426)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hero Banner', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Destacados para continuar viendo y descubrir nuevo contenido.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HomeNavRow(),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Continue Watching', route: '/continue'),
          _HomeMapRow(
            items: continueWatching.take(12).toList(growable: false),
            titleKey: 'title',
            imageKey: null,
            onTapBuilder: (item) {
              final id = item['id']?.toString() ?? '';
              final title = item['title']?.toString() ?? 'Contenido';
              final type = item['type']?.toString() ?? 'live';
              final ext = item['ext']?.toString() ?? '';
              return () => context.push('/player?title=${Uri.encodeComponent(title)}&id=$id&type=$type&ext=$ext');
            },
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Live TV Categories', route: '/live'),
          liveAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.iconUrl,
              onTapBuilder: (item) =>
                  () => context.push('/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=live'),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Popular Movies', route: '/movies'),
          vodAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) => () => context.push(
                '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
              ),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Popular Series', route: '/series'),
          seriesAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) =>
                  () => context.push('/series/details?id=${item.id}&title=${Uri.encodeComponent(item.name)}'),
              aspectRatio: 2 / 3,
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Recently Added', route: '/movies'),
          vodAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(12).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) => () => context.push(
                '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
              ),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Favorites', route: '/favorites'),
          _HomeMapRow(
            items: favorites.take(12).toList(growable: false),
            titleKey: 'name',
            imageKey: 'iconUrl',
            onTapBuilder: (item) {
              final id = item['id']?.toString() ?? '';
              final title = item['name']?.toString() ?? 'Favorito';
              return () => context.push('/player?title=${Uri.encodeComponent(title)}&id=$id&type=live');
            },
          ),
        ],
      ),
    );
  }
}

class _HomeNavRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String route, IconData icon})>[
      (title: 'Live TV', route: '/live', icon: Icons.live_tv),
      (title: 'Movies', route: '/movies', icon: Icons.movie_outlined),
      (title: 'Series', route: '/series', icon: Icons.tv),
      (title: 'Search', route: '/search', icon: Icons.search),
      (title: 'Favorites', route: '/favorites', icon: Icons.favorite_outline),
      (title: 'History', route: '/history', icon: Icons.history),
      (title: 'Settings', route: '/settings', icon: Icons.settings_outlined),
      (title: 'Profile', route: '/profile', icon: Icons.person_outline),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sections
          .map(
            (e) => SizedBox(
              width: 210,
              child: Card(
                child: ListTile(
                  leading: Icon(e.icon),
                  title: Text(e.title),
                  onTap: () => context.go(e.route),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: () => context.go(route), child: const Text('Ver más')),
      ],
    );
  }
}

class _HomeLoadingRow extends StatelessWidget {
  const _HomeLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _HomeEntityRow<T> extends StatelessWidget {
  const _HomeEntityRow({
    required this.items,
    required this.titleBuilder,
    required this.imageBuilder,
    required this.onTapBuilder,
    this.aspectRatio = 16 / 9,
  });

  final List<T> items;
  final String Function(T item) titleBuilder;
  final String? Function(T item) imageBuilder;
  final VoidCallback Function(T item) onTapBuilder;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('Sin contenido')));
    }

    return SizedBox(
      height: aspectRatio == 2 / 3 ? 300 : 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: aspectRatio == 2 / 3 ? 190 : 280,
            child: StitchContentCard(
              title: titleBuilder(item),
              imageUrl: imageBuilder(item),
              onTap: onTapBuilder(item),
              aspectRatio: aspectRatio,
            ),
          );
        },
      ),
    );
  }
}

class _HomeMapRow extends StatelessWidget {
  const _HomeMapRow({
    required this.items,
    required this.titleKey,
    required this.imageKey,
    required this.onTapBuilder,
  });

  final List<Map<String, dynamic>> items;
  final String titleKey;
  final String? imageKey;
  final VoidCallback Function(Map<String, dynamic> item) onTapBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 60, child: Center(child: Text('Sin contenido')));
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 280,
            child: StitchContentCard(
              title: item[titleKey]?.toString() ?? 'Contenido',
              imageUrl: imageKey == null ? null : item[imageKey!]?.toString(),
              onTap: onTapBuilder(item),
            ),
          );
        },
      ),
    );
  }
}
