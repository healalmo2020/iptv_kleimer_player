import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/search_index_item.dart';
import '../providers/library_provider.dart';
import '../providers/search_provider.dart';

const int _searchDebounceMs = int.fromEnvironment(
  'SEARCH_DEBOUNCE_MS',
  defaultValue: 120,
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounce;
  DateTime? _queryMeasureStart;
  String _queryMeasureValue = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indexAsync = ref.watch(searchIndexProvider);
    final snapshotItems = ref.watch(searchIndexSnapshotProvider);
    final snapshotDebugLine = ref.watch(searchSnapshotDebugLineProvider);
    final hasSnapshot = snapshotItems.isNotEmpty;
    final ranked = ref.watch(searchRankedItemsProvider(_debouncedQuery));
    final trendingRanked = ref.watch(searchRankedItemsProvider(''));
    final history = ref.watch(historyItemsProvider);

    final topResults = ranked.take(14).toList(growable: false);
    final liveResults = ranked
        .where((e) => e.type == SearchContentType.live)
        .take(10)
        .toList(growable: false);
    final movieResults = ranked
        .where((e) => e.type == SearchContentType.vod)
        .take(10)
        .toList(growable: false);
    final seriesResults = ranked
        .where((e) => e.type == SearchContentType.series)
        .take(10)
        .toList(growable: false);

    final trendingChips = trendingRanked
        .map((e) => e.title)
        .toSet()
        .take(6)
        .toList(growable: false);

    _emitFirstResultMetric(topResults);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050D0D), Color(0xFF081212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _SearchHeader(onBack: () => context.go('/home')),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _SearchInput(
                  controller: _controller,
                  onChanged: _onQueryChanged,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                  children: [
                    if (indexAsync.isLoading && hasSnapshot)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Usando indice local guardado. Sincronizando catalogo en segundo plano...',
                          style: TextStyle(
                            color: Color(0xFF8FA8A8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (indexAsync.isLoading && !hasSnapshot)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Sincronizando indice de busqueda...',
                          style: TextStyle(
                            color: Color(0xFF9DBABA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (indexAsync.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          hasSnapshot
                              ? 'No se pudo sincronizar el indice ahora mismo. Mostrando snapshot local.'
                              : 'No se pudo sincronizar el indice ahora mismo. Mostrando historial local.',
                          style: const TextStyle(
                            color: Color(0xFFCCB38A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (kDebugMode && snapshotDebugLine != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          snapshotDebugLine,
                          style: const TextStyle(
                            color: Color(0xFF6D8787),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    _SearchChipsSection(
                      icon: Icons.trending_up_rounded,
                      title: 'Trending Searches',
                      chips: trendingChips,
                      onTap: _applyQueryChip,
                    ),
                    const SizedBox(height: 14),
                    _SearchChipsSection(
                      icon: Icons.history_rounded,
                      title: 'Recent History',
                      chips: history
                          .map((e) => e['title']?.toString() ?? '')
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .take(6)
                          .toList(growable: false),
                      onTap: _applyQueryChip,
                      subdued: true,
                    ),
                    const SizedBox(height: 18),
                    if (topResults.isEmpty)
                      const _SearchEmpty()
                    else ...[
                      _buildResultSection(
                        context: context,
                        title: 'Top Match Results',
                        items: topResults,
                      ),
                      _buildResultSection(
                        context: context,
                        title: 'Live',
                        items: liveResults,
                      ),
                      _buildResultSection(
                        context: context,
                        title: 'Movies',
                        items: movieResults,
                      ),
                      _buildResultSection(
                        context: context,
                        title: 'Series',
                        items: seriesResults,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onQueryChanged(String value) {
    final normalized = value.trim().toLowerCase();
    _debounce?.cancel();

    if (normalized.isNotEmpty) {
      _queryMeasureStart = DateTime.now();
      _queryMeasureValue = normalized;
    } else {
      _queryMeasureStart = null;
      _queryMeasureValue = '';
    }

    setState(() {
      _query = normalized;
    });

    if (normalized.isEmpty || _searchDebounceMs <= 0) {
      setState(() {
        _debouncedQuery = _query;
      });
      return;
    }

    _debounce = Timer(Duration(milliseconds: _searchDebounceMs), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _debouncedQuery = _query;
      });
    });
  }

  void _emitFirstResultMetric(List<SearchIndexItem> topResults) {
    if (!kDebugMode || _queryMeasureStart == null) {
      return;
    }

    if (_debouncedQuery.isEmpty || _debouncedQuery != _queryMeasureValue) {
      return;
    }

    if (topResults.isEmpty) {
      return;
    }

    final elapsedMs = DateTime.now()
        .difference(_queryMeasureStart!)
        .inMilliseconds;
    debugPrint(
      '[search_metric] query="$_debouncedQuery" firstResultMs=$elapsedMs total=${topResults.length}',
    );

    _queryMeasureStart = null;
    _queryMeasureValue = '';
  }

  void _applyQueryChip(String value) {
    _controller.text = value;
    _onQueryChanged(value);
  }

  Widget _buildResultSection({
    required BuildContext context,
    required String title,
    required List<SearchIndexItem> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              Text(
                '${items.length} results',
                style: const TextStyle(
                  color: Color(0xFF6F8F8F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 1200 ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 16 / 9,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => context.push(
                  '/player?title=${Uri.encodeComponent(item.title)}&id=${item.id}&type=${item.playerType}&ext=${item.extension ?? ''}',
                ),
                borderRadius: BorderRadius.circular(14),
                child: _hasNetworkPoster(item.posterUrl)
                    ? _buildPosterFilledCard(item)
                    : _buildCompactResultCard(item),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForType(SearchContentType type) {
    return switch (type) {
      SearchContentType.vod => Icons.movie_creation_outlined,
      SearchContentType.series => Icons.subscriptions_outlined,
      SearchContentType.live => Icons.live_tv_rounded,
    };
  }

  Widget _buildPosterFilledCard(SearchIndexItem item) {
    final posterUrl = item.posterUrl!.trim();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            ColoredBox(
              color: const Color(0xFF0D1A1B),
              child: _AdaptiveCachedPoster(
                imageUrl: posterUrl,
                fallback: _buildPosterFallbackBackground(item),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0xD010151A)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEAFBFB),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.type.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFAFCDCD),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF0DF2F2),
                    size: 24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterFallbackBackground(SearchIndexItem item) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF183133), Color(0xFF0F1F20)],
        ),
      ),
      child: Center(
        child: Icon(_iconForType(item.type), color: const Color(0xFF0DF2F2)),
      ),
    );
  }

  Widget _buildCompactResultCard(SearchIndexItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x220DF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForType(item.type),
              color: const Color(0xFF0DF2F2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE6F9F9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.type.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7E9B9B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: Color(0xFF0DF2F2)),
        ],
      ),
    );
  }

  bool _hasNetworkPoster(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x220DF2F2))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          const Text(
            'KLEIMER PLAYER',
            style: TextStyle(
              color: Color(0xFFE7F7F7),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x220DF2F2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x330DF2F2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.keyboard_rounded,
                  size: 14,
                  color: Color(0xFF0DF2F2),
                ),
                SizedBox(width: 4),
                Text(
                  'PRESS ENTER TO PLAY',
                  style: TextStyle(
                    color: Color(0xFF0DF2F2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xA0102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x330DF2F2), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF0DF2F2), size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: Color(0xFFE8F9F9),
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
              decoration: const InputDecoration(
                hintText: 'Find content across the galaxy...',
                hintStyle: TextStyle(color: Color(0xFF456363), fontSize: 22),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchChipsSection extends StatelessWidget {
  const _SearchChipsSection({
    required this.icon,
    required this.title,
    required this.chips,
    required this.onTap,
    this.subdued = false,
  });

  final IconData icon;
  final String title;
  final List<String> chips;
  final ValueChanged<String> onTap;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final fg = subdued ? const Color(0xFF8A9F9F) : const Color(0xFF0DF2F2);
    final bg = subdued ? const Color(0x40102121) : const Color(0x220DF2F2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map(
                (chip) => InkWell(
                  onTap: () => onTap(chip),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x220DF2F2)),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: subdued
                            ? const Color(0xFFA8B9B9)
                            : const Color(0xFFE8F8F8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0x66102222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: const Center(
        child: Text(
          'No results found in this sector.',
          style: TextStyle(
            color: Color(0xFF8BA3A3),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AdaptiveCachedPoster extends StatefulWidget {
  const _AdaptiveCachedPoster({
    required this.imageUrl,
    required this.fallback,
  });

  final String imageUrl;
  final Widget fallback;

  @override
  State<_AdaptiveCachedPoster> createState() => _AdaptiveCachedPosterState();
}

class _AdaptiveCachedPosterState extends State<_AdaptiveCachedPoster> {
  static const double _coverAspectThreshold = 1.15;

  BoxFit _fit = BoxFit.contain;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageRatio();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveCachedPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _fit = BoxFit.contain;
      _resolveImageRatio();
    }
  }

  @override
  void dispose() {
    _disposeImageListener();
    super.dispose();
  }

  void _resolveImageRatio() {
    final provider = CachedNetworkImageProvider(widget.imageUrl);
    final stream = provider.resolve(createLocalImageConfiguration(context));

    final oldStream = _stream;
    final oldListener = _listener;
    if (oldStream != null && oldListener != null) {
      oldStream.removeListener(oldListener);
    }

    _stream = stream;
    _listener = ImageStreamListener(
      (imageInfo, _) {
        final image = imageInfo.image;
        if (image.height <= 0) {
          return;
        }

        final aspect = image.width / image.height;
        final nextFit =
            aspect >= _coverAspectThreshold ? BoxFit.cover : BoxFit.contain;
        if (!mounted || nextFit == _fit) {
          return;
        }

        setState(() {
          _fit = nextFit;
        });
      },
    );

    stream.addListener(_listener!);
  }

  void _disposeImageListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: _fit,
      alignment: Alignment.center,
      filterQuality: FilterQuality.low,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, url) => widget.fallback,
      errorWidget: (context, url, error) => widget.fallback,
    );
  }
}
