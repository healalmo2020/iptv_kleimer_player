import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/channel_logo_resolver.dart';
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
          vodAsync.when(
            data: (items) => _HeroBannerCarousel(items: items),
            loading: () => _HeroBannerSkeleton(
              height: MediaQuery.sizeOf(context).height * 0.7,
            ),
            error: (_, _) => _HeroBannerSkeleton(
              height: MediaQuery.sizeOf(context).height * 0.7,
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
              return () => context.push(
                '/player?title=${Uri.encodeComponent(title)}&id=$id&type=$type&ext=$ext',
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Live TV Categories', route: '/live'),
          liveAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => resolveChannelLogoUrl(
                channelName: item.name,
                primaryIconUrl: item.iconUrl,
              ),
              onTapBuilder: (item) =>
                  () => context.push(
                    '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=live',
                  ),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Popular Movies', route: '/movies'),
          vodAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) =>
                  () => context.push(
                    '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
                  ),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Popular Series', route: '/series'),
          seriesAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(20).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) =>
                  () => context.push(
                    '/series/details?id=${item.id}&title=${Uri.encodeComponent(item.name)}',
                  ),
              aspectRatio: 2 / 3,
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Recently Added', route: '/movies'),
          vodAsync.when(
            data: (items) => _HomeEntityRow(
              items: items.take(12).toList(growable: false),
              titleBuilder: (item) => item.name,
              imageBuilder: (item) => item.coverUrl,
              onTapBuilder: (item) =>
                  () => context.push(
                    '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
                  ),
            ),
            loading: () => const _HomeLoadingRow(),
            error: (_, _) => const SizedBox.shrink(),
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
              return () => context.push(
                '/player?title=${Uri.encodeComponent(title)}&id=$id&type=live',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroBannerSkeleton extends StatelessWidget {
  const _HeroBannerSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hero Banner',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Destacados para continuar viendo y descubrir nuevo contenido.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBannerCarousel extends StatefulWidget {
  const _HeroBannerCarousel({required this.items});

  final List<dynamic> items;

  @override
  State<_HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<_HeroBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoSlide;
  int _index = 0;

  List<dynamic> get _selected {
    final withCover = widget.items
        .where((item) => (item.coverUrl?.toString().isNotEmpty ?? false))
        .toList(growable: false);
    final movies2026 = withCover
        .where((item) => item.name.toString().contains('2026'))
        .toList(growable: false);
    final source = movies2026.isNotEmpty ? movies2026 : withCover;
    if (source.isEmpty) {
      return widget.items.take(10).toList(growable: false);
    }
    return source.take(10).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _autoSlide = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) {
        return;
      }
      final items = _selected;
      if (items.length <= 1 || !_pageController.hasClients) {
        return;
      }
      final next = (_index + 1) % items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSlide?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _selected;
    final height = MediaQuery.sizeOf(context).height * 0.7;

    if (items.isEmpty) {
      return _HeroBannerSkeleton(height: height);
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (value) {
                setState(() {
                  _index = value;
                });
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.coverUrl.toString(),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: Color(0xFF162544)),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x1A000000), Color(0xFF0B1426)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Builder(
                builder: (context) {
                  final current = items[_index.clamp(0, items.length - 1)];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => context.push(
                          '/player?title=${Uri.encodeComponent(current.name.toString())}&id=${current.id}&type=vod&ext=${current.containerExtension ?? ''}',
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Reproducir ahora'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
        TextButton(
          onPressed: () => context.go(route),
          child: const Text('Ver más'),
        ),
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
      return const SizedBox(
        height: 60,
        child: Center(child: Text('Sin contenido')),
      );
    }

    return SizedBox(
      height: aspectRatio == 2 / 3 ? 300 : 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
      return const SizedBox(
        height: 60,
        child: Center(child: Text('Sin contenido')),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
