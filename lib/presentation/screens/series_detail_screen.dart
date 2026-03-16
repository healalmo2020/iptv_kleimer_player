import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/series_episode.dart';
import '../providers/series_provider.dart';
import '../widgets/stitch_async_state.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.title,
  });

  final String seriesId;
  final String title;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(seriesEpisodesProvider(widget.seriesId));

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
          child: episodesAsync.when(
            loading: () => const StitchInlineLoader(),
            error: (error, _) =>
                StitchErrorPanel(message: 'Episode error: $error'),
            data: (episodes) {
              if (episodes.isEmpty) {
                return const Center(
                  child: Text(
                    'No episodes available.',
                    style: TextStyle(color: Color(0xFF89A6A6)),
                  ),
                );
              }

              final grouped = <int, List<SeriesEpisode>>{};
              for (final episode in episodes) {
                grouped
                    .putIfAbsent(episode.season, () => <SeriesEpisode>[])
                    .add(episode);
              }

              final seasons = grouped.keys.toList()..sort();
              _selectedSeason ??= seasons.first;
              if (!seasons.contains(_selectedSeason)) {
                _selectedSeason = seasons.first;
              }

              final selectedEpisodes =
                  grouped[_selectedSeason] ?? const <SeriesEpisode>[];

              return Column(
                children: [
                  _SeriesHeader(
                    title: widget.title,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/home');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.subscriptions_rounded,
                          color: Color(0xFF0DF2F2),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SEASONS',
                          style: TextStyle(
                            color: Color(0xFF0DF2F2),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: seasons
                                  .map(
                                    (season) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        selected: season == _selectedSeason,
                                        label: Text('SEASON $season'),
                                        labelStyle: TextStyle(
                                          color: season == _selectedSeason
                                              ? const Color(0xFF081212)
                                              : const Color(0xFFE6F8F8),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                        selectedColor: const Color(0xFF0DF2F2),
                                        backgroundColor: const Color(
                                          0x66102222,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0x220DF2F2),
                                        ),
                                        onSelected: (_) => setState(
                                          () => _selectedSeason = season,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width > 1220
                            ? 4
                            : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: selectedEpisodes.length,
                      itemBuilder: (context, index) {
                        final episode = selectedEpisodes[index];
                        final nextEpisode = _findNextEpisode(episodes, episode);
                        final episodeTitle =
                            'T${episode.season} E${episode.episodeNumber} - ${episode.title}';
                        final isFocusPreview = index == 0;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            final nextParams = nextEpisode == null
                                ? ''
                                : '&nextId=${nextEpisode.id}&nextTitle=${Uri.encodeComponent(nextEpisode.title)}&nextExt=${nextEpisode.containerExtension ?? ''}';

                            context.push(
                              '/player?title=${Uri.encodeComponent(episodeTitle)}&id=${episode.id}&type=series&ext=${episode.containerExtension ?? ''}$nextParams',
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFocusPreview
                                  ? const Color(0x33102222)
                                  : const Color(0x55102222),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFocusPreview
                                    ? const Color(0xFF0DF2F2)
                                    : const Color(0x220DF2F2),
                                width: isFocusPreview ? 2 : 1,
                              ),
                              boxShadow: isFocusPreview
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x660DF2F2),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFocusPreview
                                              ? const Color(0x220DF2F2)
                                              : const Color(0x221D3131),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${episode.episodeNumber}'.padLeft(
                                            2,
                                            '0',
                                          ),
                                          style: TextStyle(
                                            color: isFocusPreview
                                                ? const Color(0xFF0DF2F2)
                                                : const Color(0xFF8AA7A7),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: isFocusPreview
                                            ? const Color(0xFF0DF2F2)
                                            : const Color(0xFFA2BABA),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    episode.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isFocusPreview
                                          ? const Color(0xFFE8F9F9)
                                          : const Color(0xFFD2E6E6),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Runtime ~ 45m',
                                    style: const TextStyle(
                                      color: Color(0xFF789393),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  SeriesEpisode? _findNextEpisode(
    List<SeriesEpisode> episodes,
    SeriesEpisode current,
  ) {
    final index = episodes.indexWhere((e) => e.id == current.id);
    if (index < 0 || index + 1 >= episodes.length) {
      return null;
    }
    return episodes[index + 1];
  }
}

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE7F8F8),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Original Series • Scifi Thriller',
                  style: TextStyle(color: Color(0xFF7D9999), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x220DF2F2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x330DF2F2)),
            ),
            child: const Text(
              'EPISODES',
              style: TextStyle(
                color: Color(0xFF0DF2F2),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
