import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/channel_logo_resolver.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/live_provider.dart';
import '../../providers/parental_provider.dart';
import '../../widgets/stitch_content_card.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final ScrollController _categoriesScrollController = ScrollController();
  String? _selectedCategoryId;

  @override
  void dispose() {
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/home');
          },
        ),
        title: const Text('Live TV'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: categories.when(
              data: (data) {
                if (data.isEmpty) {
                  return const Center(child: Text('No hay categorías.'));
                }

                final selectedExists = data.any((e) => e.id == _selectedCategoryId);
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
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _scrollCategoriesBy(-260),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _categoriesScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _categoriesScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          itemCount: data.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = data[index];
                            final selected =
                                category.id == _selectedCategoryId;
                            return ChoiceChip(
                              selected: selected,
                              label: Text(category.name),
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategoryId = category.id;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _scrollCategoriesBy(260),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error categorías: $error')),
            ),
          ),
          Expanded(
            child: streams.when(
              data: (items) {
                if (_selectedCategoryId == null) {
                  return const Center(child: CircularProgressIndicator());
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

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No hay canales en esta categoría.'),
                  );
                }

                return GridView.builder(
                  cacheExtent: 120,
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 16 / 9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final stream = filteredItems[index];
                    final isFavorite = favorites.contains(stream.id);
                    final repositoryLogo = resolveChannelLogoRepositoryUrl(
                      channelName: stream.name,
                    );
                    final primaryLogo =
                        repositoryLogo.isEmpty ? stream.iconUrl : repositoryLogo;
                    final fallbackLogo =
                        repositoryLogo.isEmpty ? null : stream.iconUrl;
                    return StitchContentCard(
                      title: stream.name,
                      imageUrl: primaryLogo,
                      fallbackImageUrl: fallbackLogo,
                      imageCacheWidth: 320,
                      imageCacheHeight: 180,
                      imageFit: BoxFit.contain,
                      useShimmerPlaceholder: false,
                      onTap: () => context.push(
                        '/player?title=${Uri.encodeComponent(stream.name)}&id=${stream.id}&type=live',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.schedule),
                            color: Colors.white,
                            onPressed: () => _showEpg(
                              context,
                              ref,
                              stream.id,
                              stream.name,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                            color: isFavorite
                                ? const Color(0xFFFF5252)
                                : Colors.white,
                            onPressed: () => ref
                                .read(favoritesProvider.notifier)
                                .toggle(stream),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error streams: $error')),
            ),
          ),
        ],
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
      showDragHandle: true,
      builder: (_) {
        final epgAsync = ref.watch(liveEpgProvider(streamId));
        return SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'EPG • $streamName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: epgAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error EPG: $error')),
                  data: (events) {
                    if (events.isEmpty) {
                      return const Center(
                        child: Text('No hay programación disponible.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

                        return ListTile(
                          tileColor: const Color(0xFF162544),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          title: Text(event.title),
                          subtitle: Text('$start - $end\n${event.description}'),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
