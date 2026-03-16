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
    final isCompact = MediaQuery.sizeOf(context).width < 1000;

    final issues = <String>[];
    if (liveAsync.hasError) {
      issues.add('Live TV: ${liveAsync.error}');
    }
    if (vodAsync.hasError) {
      issues.add('Peliculas: ${vodAsync.error}');
    }
    if (seriesAsync.hasError) {
      issues.add('Series: ${seriesAsync.error}');
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050C0C), Color(0xFF081212), Color(0xFF0B1717)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            if (!isCompact) const _StitchSidebar(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(isCompact ? 16 : 20, 16, 16, 24),
                children: [
                  if (isCompact) const _CompactTopBar(),
                  if (issues.isNotEmpty) ...[
                    _AsyncIssuesBanner(issues: issues),
                    const SizedBox(height: 14),
                  ],
                  vodAsync.when(
                    data: (items) => _HeroBannerCarousel(items: items),
                    loading: () => _HeroBannerSkeleton(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                    ),
                    error: (_, _) => _HeroBannerSkeleton(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    error: (_, _) =>
                        const _HomeErrorRow(label: 'Live TV no disponible'),
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
                    error: (_, _) => const _HomeErrorRow(
                      label: 'Catalogo VOD no disponible',
                    ),
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
                    error: (_, _) =>
                        const _HomeErrorRow(label: 'Series no disponibles'),
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
                    error: (_, _) =>
                        const _HomeErrorRow(label: 'Sin recientes'),
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
                  const SizedBox(height: 20),
                  const _SystemStatusStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0DF2F2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x800DF2F2),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.play_circle_fill, color: Color(0xFF081212)),
          ),
          const SizedBox(width: 10),
          Text(
            'KLEIMER PLAYER',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StitchSidebar extends StatelessWidget {
  const _StitchSidebar();

  @override
  Widget build(BuildContext context) {
    final items = <({String route, IconData icon})>[
      (route: '/home', icon: Icons.home_rounded),
      (route: '/live', icon: Icons.live_tv_rounded),
      (route: '/movies', icon: Icons.movie_creation_outlined),
      (route: '/series', icon: Icons.tv_rounded),
      (route: '/search', icon: Icons.search_rounded),
      (route: '/settings', icon: Icons.tune_rounded),
    ];

    return Container(
      width: 84,
      decoration: const BoxDecoration(
        color: Color(0xC0102222),
        border: Border(right: BorderSide(color: Color(0x220DF2F2))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0DF2F2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x800DF2F2),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_circle_fill,
              color: Color(0xFF081212),
              size: 34,
            ),
          ),
          const SizedBox(height: 28),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: () => context.go(item.route),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.route == '/home'
                        ? const Color(0x220DF2F2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.route == '/home'
                        ? const Color(0xFF0DF2F2)
                        : const Color(0xFF8BA3A3),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => context.go('/login'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFF8BA3A3)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AsyncIssuesBanner extends StatelessWidget {
  const _AsyncIssuesBanner({required this.issues});

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x26FF4D4D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x59FF4D4D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFFF4D4D)),
              SizedBox(width: 8),
              Text(
                'Problemas de conexion detectados',
                style: TextStyle(
                  color: Color(0xFFFFB3B3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...issues
              .take(3)
              .map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    issue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFFFD9D9)),
                  ),
                ),
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
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF102222), Color(0xFF081212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x330DF2F2)),
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cargando destacados para continuar viendo y descubrir contenido nuevo.',
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
        borderRadius: BorderRadius.circular(20),
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
                    const ColoredBox(color: Color(0xFF162544)),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bannerAspectRatio = constraints.maxHeight <= 0
                            ? 16 / 9
                            : constraints.maxWidth / constraints.maxHeight;
                        return _AdaptiveHeroBannerImage(
                          imageUrl: item.coverUrl.toString(),
                          bannerAspectRatio: bannerAspectRatio,
                        );
                      },
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x33000000), Color(0xFF081212)],
                          begin: Alignment.topRight,
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
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0DF2F2),
                          foregroundColor: const Color(0xFF081212),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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

class _AdaptiveHeroBannerImage extends StatefulWidget {
  const _AdaptiveHeroBannerImage({
    required this.imageUrl,
    required this.bannerAspectRatio,
  });

  final String imageUrl;
  final double bannerAspectRatio;

  @override
  State<_AdaptiveHeroBannerImage> createState() =>
      _AdaptiveHeroBannerImageState();
}

class _AdaptiveHeroBannerImageState extends State<_AdaptiveHeroBannerImage> {
  late ImageProvider _provider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _provider = CachedNetworkImageProvider(widget.imageUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveHeroBannerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl == widget.imageUrl) {
      return;
    }
    _provider = CachedNetworkImageProvider(widget.imageUrl);
    _imageAspectRatio = null;
    _stopListening();
    _resolveAspectRatio();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key == stream.key) {
      return;
    }

    _stopListening();
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener((imageInfo, _) {
      final height = imageInfo.image.height.toDouble();
      if (height <= 0) {
        return;
      }
      final nextAspectRatio = imageInfo.image.width.toDouble() / height;
      if (!mounted || _imageAspectRatio == nextAspectRatio) {
        return;
      }
      setState(() {
        _imageAspectRatio = nextAspectRatio;
      });
    });
    stream.addListener(_imageStreamListener!);
  }

  void _stopListening() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream == null || listener == null) {
      return;
    }
    stream.removeListener(listener);
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final fit = _selectFit();
    return Image(
      image: _provider,
      fit: fit,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF162544)),
    );
  }

  BoxFit _selectFit() {
    final imageAspectRatio = _imageAspectRatio;
    if (imageAspectRatio == null) {
      return BoxFit.contain;
    }

    final coverThreshold = widget.bannerAspectRatio * 0.9;
    return imageAspectRatio >= coverThreshold ? BoxFit.cover : BoxFit.contain;
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
              width: 220,
              child: InkWell(
                onTap: () => context.go(e.route),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x80102222),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x220DF2F2)),
                  ),
                  child: Row(
                    children: [
                      Icon(e.icon, color: const Color(0xFF0DF2F2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.title,
                          style: const TextStyle(
                            color: Color(0xFFE9F8F8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF83A3A3),
                      ),
                    ],
                  ),
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
        Row(
          children: [
            Container(
              width: 6,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF0DF2F2),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x800DF2F2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        TextButton(
          onPressed: () => context.go(route),
          child: const Text('Ver mas'),
        ),
      ],
    );
  }
}

class _HomeLoadingRow extends StatelessWidget {
  const _HomeLoadingRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _HomeErrorRow extends StatelessWidget {
  const _HomeErrorRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0x26FF4D4D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x59FF4D4D)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFB3B3),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SystemStatusStrip extends StatelessWidget {
  const _SystemStatusStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: const Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(
            'SYSTEM: OPERATIONAL',
            style: TextStyle(color: Color(0xFF88A8A8), fontSize: 11),
          ),
          Text(
            'LATENCY: 14ms',
            style: TextStyle(color: Color(0xFF88A8A8), fontSize: 11),
          ),
          Text(
            'REGION: SECTOR-7',
            style: TextStyle(color: Color(0xFF88A8A8), fontSize: 11),
          ),
        ],
      ),
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
