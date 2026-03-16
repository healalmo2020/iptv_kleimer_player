import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/simple_title_search.dart';
import '../../domain/entities/vod_category.dart';
import '../../domain/entities/vod_stream.dart';
import '../providers/parental_provider.dart';
import '../providers/vod_provider.dart';
import '../widgets/library_inline_search_box.dart';
import '../widgets/stitch_async_state.dart';
import '../widgets/stitch_content_card.dart';

const String _allMoviesCategoryId = '__all_movies__';
const VodCategory _allMoviesCategory = VodCategory(
  id: _allMoviesCategoryId,
  name: 'All',
  parentId: '0',
);

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  String? _selectedCategoryId;
  final ScrollController _categoriesScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _movieQuery = '';

  @override
  void dispose() {
    _categoriesScrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
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
    final categoriesAsync = ref.watch(vodCategoriesProvider);
    final streamsAsync = ref.watch(vodStreamsProvider);
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081212), Color(0xFF102222)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _MoviesHeader(
                onBack: () => context.go('/home'),
                searchController: _searchController,
                onSearchChanged: _onMovieQueryChanged,
                onClearSearch: _clearMovieQuery,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: categoriesAsync.when(
                  data: (categories) {
                    final effectiveCategories = <VodCategory>[
                      _allMoviesCategory,
                      ...categories,
                    ];

                    if (effectiveCategories.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final hasSelected = effectiveCategories.any(
                      (category) => category.id == _selectedCategoryId,
                    );
                    if (_selectedCategoryId == null || !hasSelected) {
                      _selectedCategoryId = _allMoviesCategoryId;
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
                              children: effectiveCategories
                                  .map(
                                    (category) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        selected:
                                            category.id == _selectedCategoryId,
                                        label: Text(category.name),
                                        labelStyle: TextStyle(
                                          color:
                                              category.id == _selectedCategoryId
                                              ? const Color(0xFF081212)
                                              : const Color(0xFFE8F9F9),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        selectedColor: const Color(0xFF0DF2F2),
                                        backgroundColor: const Color(
                                          0x66102222,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0x220DF2F2),
                                        ),
                                        onSelected: (_) => setState(
                                          () =>
                                              _selectedCategoryId = category.id,
                                        ),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: streamsAsync.when(
                    data: (streams) {
                      final isAllCategorySelected =
                          _selectedCategoryId == null ||
                          _selectedCategoryId == _allMoviesCategoryId;

                      var filtered = isAllCategorySelected
                          ? streams
                          : streams
                                .where(
                                  (e) => e.categoryId == _selectedCategoryId,
                                )
                                .toList(growable: false);

                      if (isAllCategorySelected) {
                        filtered = [...filtered]
                          ..sort(
                            (a, b) => a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            ),
                          );
                      }

                      if (parental.enabled) {
                        filtered = filtered
                            .where((e) => !_isAdultContent(e.name))
                            .toList(growable: false);
                      }

                      filtered = _applyMovieQuery(filtered);

                      if (filtered.isEmpty) {
                        return const _EmptyGrid(
                          label: 'No movies in this category.',
                        );
                      }

                      final width = MediaQuery.sizeOf(context).width;
                      final crossAxisCount = width > 1500
                          ? 5
                          : width > 1180
                          ? 4
                          : width > 860
                          ? 3
                          : 2;

                      return GridView.builder(
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 16 / 9,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: StitchContentCard(
                                  title: item.name,
                                  imageUrl: item.coverUrl,
                                  onTap: () => context.push(
                                    '/player?title=${Uri.encodeComponent(item.name)}&id=${item.id}&type=vod&ext=${item.containerExtension ?? ''}',
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x99081212),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0x330DF2F2),
                                    ),
                                  ),
                                  child: Text(
                                    (item.containerExtension ?? 'AUTO')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF0DF2F2),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => GridView.builder(
                      itemCount: 10,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 16 / 9,
                          ),
                      itemBuilder: (context, index) => Container(
                        decoration: BoxDecoration(
                          color: const Color(0x331A3333),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x220DF2F2)),
                        ),
                      ),
                    ),
                    error: (error, _) =>
                        _EmptyGrid(label: 'Movie error: $error'),
                  ),
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

  void _onMovieQueryChanged(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    _searchDebounce?.cancel();

    if (normalized.isEmpty) {
      setState(() {
        _movieQuery = '';
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _movieQuery = normalized;
      });
    });
  }

  void _clearMovieQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _movieQuery = '';
    });
  }

  List<VodStream> _applyMovieQuery(List<VodStream> streams) {
    return applySimpleTitleQuery<VodStream>(
      items: streams,
      query: _movieQuery,
      titleSelector: (item) => item.name,
    );
  }
}

class _MoviesHeader extends StatelessWidget {
  const _MoviesHeader({
    required this.onBack,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final VoidCallback onBack;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Expanded(
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE6F8F8), Color(0xFF0DF2F2)],
                  ).createShader(bounds),
                  child: const Text(
                    'Movies Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: LibraryInlineSearchBox(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onClear: onClearSearch,
                      hintText: 'Buscar películas...',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _HeaderChip(icon: Icons.filter_list_rounded, label: 'Filter'),
          const SizedBox(width: 8),
          _HeaderChip(icon: Icons.sort_rounded, label: 'Newest'),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x220DF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0DF2F2)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE7F8F8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x220DF2F2)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF88A3A3),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
