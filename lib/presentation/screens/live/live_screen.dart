import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/channel_logo_resolver.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/live_provider.dart';
import '../../providers/parental_provider.dart';
import '../../providers/logo_resolver_provider.dart';
import '../../widgets/stitch_async_state.dart';
import '../../widgets/stitch_content_card.dart';
import '../../widgets/library_inline_search_box.dart';
import '../../../core/utils/simple_title_search.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final ScrollController _categoriesScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _categoriesScrollController.dispose();
    super.dispose();
  }

  void _scrollCategoriesBy(double delta) {
    if (!_categoriesScrollController.hasClients) {
      return;
    }
    final position = _categoriesScrollController.position;
    final target = (_categoriesScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _categoriesScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(liveCategoriesProvider);
    final streams = ref.watch(
      liveStreamsByCategoryProvider(_selectedCategoryId),
    );
    final favorites = ref.watch(favoritesProvider);
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF071111), Color(0xFF0D1D1D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _LiveHeader(
                onBack: () => context.go('/home'),
                searchController: _searchController,
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                onSearchClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: categories.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const SizedBox(
                        height: 50,
                        child: Center(child: Text('No categories found.')),
                      );
                    }

                    final selectedExists = data.any(
                      (e) => e.id == _selectedCategoryId,
                    );
                    if (_selectedCategoryId == null || !selectedExists) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _selectedCategoryId = data.first.id;
                        });
                      });
                    }

                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: const Color(0xFF0DF2F2),
                          onPressed: () => _scrollCategoriesBy(-260),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _categoriesScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: data
                                  .map(
                                    (category) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        selected:
                                            category.id == _selectedCategoryId,
                                        selectedColor: const Color(0xFF0DF2F2),
                                        backgroundColor: const Color(
                                          0x66102222,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0x220DF2F2),
                                        ),
                                        label: Text(category.name),
                                        labelStyle: TextStyle(
                                          color:
                                              category.id == _selectedCategoryId
                                              ? const Color(0xFF081212)
                                              : const Color(0xFFE7F9F9),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedCategoryId = category.id;
                                          });
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: const Color(0xFF0DF2F2),
                          onPressed: () => _scrollCategoriesBy(260),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const SizedBox(height: 50, child: StitchInlineLoader()),
                  error: (error, _) =>
                      StitchErrorStrip(message: 'Category error: $error'),
                ),
              ),
              Expanded(
                child: streams.when(
                  data: (items) {
                    if (_selectedCategoryId == null) {
                      return const StitchInlineLoader();
                    }

                    var filteredItems = _selectedCategoryId == null
                        ? items
                        : items
                              .where((e) => e.categoryId == _selectedCategoryId)
                              .toList(growable: false);

                    if (parental.enabled) {
                      filteredItems = filteredItems
                          .where((e) => !_isAdultContent(e.name))
                          .toList(growable: false);
                    }

                    if (_searchQuery.isNotEmpty) {
                      filteredItems = applySimpleTitleQuery(
                        items: filteredItems,
                        query: _searchQuery,
                        titleSelector: (e) => e.name,
                      );
                    }

                    if (filteredItems.isEmpty) {
                      return const Center(
                        child: Text(
                          'No channels in this category.',
                          style: TextStyle(
                            color: Color(0xFF84A0A0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    final width = MediaQuery.sizeOf(context).width;
                    final crossAxisCount = width > 1450
                        ? 4
                        : width > 1080
                        ? 3
                        : 2;

                    return GridView.builder(
                      cacheExtent: 120,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 16 / 9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final stream = filteredItems[index];
                        final isFavorite = favorites.contains(stream.id);
                        final logoIndex = ref.watch(logoResolverProvider);
                        
                        // Deduce country from category name (e.g., "TV | HONDURAS" -> "HONDURAS")
                        String? deducedCountry;
                        final currentCategory = categories.value?.any((c) => c.id == _selectedCategoryId) == true
                            ? categories.value?.firstWhere((c) => c.id == _selectedCategoryId)
                            : null;
                        
                        if (currentCategory != null) {
                          final name = currentCategory.name;
                          if (name.contains('|')) {
                            deducedCountry = name.split('|').last.trim();
                          } else {
                            deducedCountry = name;
                          }
                        }

                        final logoUrl = resolveChannelLogoUrl(
                          channelName: stream.name,
                          primaryIconUrl: stream.iconUrl,
                          jsonIndex: logoIndex,
                          country: deducedCountry,
                        );

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: StitchContentCard(
                                title: stream.name,
                                imageUrl: logoUrl,
                                imageFit: BoxFit.contain,
                                useShimmerPlaceholder: false,
                                onTap: () => context.push(
                                  '/player?title=${Uri.encodeComponent(stream.name)}&id=${stream.id}&type=live',
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Row(
                                children: [
                                  _ActionPill(
                                    icon: Icons.schedule_rounded,
                                    color: const Color(0xFF0DF2F2),
                                    onTap: () => _showEpg(
                                      context,
                                      ref,
                                      stream.id,
                                      stream.name,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _ActionPill(
                                    icon: isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFavorite
                                        ? const Color(0xFFFF5F52)
                                        : const Color(0xFFE4F9F9),
                                    onTap: () => ref
                                        .read(favoritesProvider.notifier)
                                        .toggle(stream),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const StitchInlineLoader(),
                  error: (error, _) =>
                      StitchErrorPanel(message: 'Streams error: $error'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAdultContent(String title) {
    final value = title.toLowerCase();
    return value.contains('adult') ||
        value.contains('xxx') ||
        value.contains('+18');
  }

  Future<void> _showEpg(
    BuildContext context,
    WidgetRef ref,
    String streamId,
    String streamName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF081212),
      showDragHandle: true,
      builder: (_) {
        final epgAsync = ref.watch(liveEpgProvider(streamId));
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.live_tv_rounded, color: Color(0xFF0DF2F2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EPG • $streamName',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x220DF2F2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x220DF2F2)),
                      ),
                      child: const Text(
                        'LIVE GUIDE',
                        style: TextStyle(
                          color: Color(0xFF0DF2F2),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: epgAsync.when(
                    loading: () => const StitchInlineLoader(),
                    error: (error, _) =>
                        StitchErrorPanel(message: 'EPG error: $error'),
                    data: (events) {
                      if (events.isEmpty) {
                        return const Center(
                          child: Text(
                            'No EPG data available.',
                            style: TextStyle(color: Color(0xFF87A4A4)),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final start = event.start == null
                              ? '--:--'
                              : '${event.start!.hour.toString().padLeft(2, '0')}:${event.start!.minute.toString().padLeft(2, '0')}';
                          final end = event.end == null
                              ? '--:--'
                              : '${event.end!.hour.toString().padLeft(2, '0')}:${event.end!.minute.toString().padLeft(2, '0')}';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0x66102222),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x220DF2F2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x220DF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$start - $end',
                                        style: const TextStyle(
                                          color: Color(0xFF0DF2F2),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    color: Color(0xFFE6F9F9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.description,
                                  style: const TextStyle(
                                    color: Color(0xFF8AA7A7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.onBack,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  final VoidCallback onBack;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0x80102222),
        border: Border(bottom: BorderSide(color: Color(0x220DF2F2))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Text(
            'Live TV Guide',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          const _LiveDot(),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Color(0xFF0DF2F2),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: LibraryInlineSearchBox(
              controller: searchController,
              onChanged: onSearchChanged,
              onClear: onSearchClear,
              hintText: 'Search channels',
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFFF5F52),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xAA081212),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x220DF2F2)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}
