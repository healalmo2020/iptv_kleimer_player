import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/simple_title_search.dart';
import '../../domain/entities/series_item.dart';
import '../providers/parental_provider.dart';
import '../providers/series_provider.dart';
import '../widgets/library_inline_search_box.dart';
import '../widgets/stitch_async_state.dart';
import '../widgets/stitch_content_card.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _seriesQuery = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(seriesProvider);
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
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE6F8F8), Color(0xFF0DF2F2)],
          ).createShader(bounds),
          child: const Text(
            'Series Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: LibraryInlineSearchBox(
              controller: _searchController,
              onChanged: _onSeriesQueryChanged,
              onClear: _clearSeriesQuery,
              hintText: 'Buscar series...',
            ),
          ),
        ),
      ),
      body: seriesAsync.when(
        loading: () => const StitchInlineLoader(),
        error: (error, _) => StitchErrorPanel(message: 'Series error: $error'),
        data: (items) {
          final filteredBase = parental.enabled
              ? items
                    .where((e) => !_isAdultContent(e.name))
                    .toList(growable: false)
              : items;

          final filtered = _applySeriesQuery(filteredBase);

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
    return value.contains('adult') ||
        value.contains('xxx') ||
        value.contains('+18');
  }

  void _onSeriesQueryChanged(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    _searchDebounce?.cancel();

    if (normalized.isEmpty) {
      setState(() {
        _seriesQuery = '';
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _seriesQuery = normalized;
      });
    });
  }

  void _clearSeriesQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _seriesQuery = '';
    });
  }

  List<SeriesItem> _applySeriesQuery(List<SeriesItem> items) {
    return applySimpleTitleQuery<SeriesItem>(
      items: items,
      query: _seriesQuery,
      titleSelector: (item) => item.name,
    );
  }
}
