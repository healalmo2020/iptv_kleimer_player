import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/series_episode.dart';
import '../providers/series_provider.dart';

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.title,
  });

  final String seriesId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(seriesEpisodesProvider(seriesId));

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
        title: Text(title),
      ),
      body: episodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error episodios: $error')),
        data: (episodes) {
          if (episodes.isEmpty) {
            return const Center(child: Text('No hay episodios disponibles.'));
          }

          final grouped = <int, List<SeriesEpisode>>{};
          for (final episode in episodes) {
            grouped
                .putIfAbsent(episode.season, () => <SeriesEpisode>[])
                .add(episode);
          }

          final seasons = grouped.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: seasons.length,
            itemBuilder: (context, seasonIndex) {
              final season = seasons[seasonIndex];
              final seasonEpisodes = grouped[season]!;

              return Card(
                child: ExpansionTile(
                  title: Text('Temporada $season'),
                  children: List.generate(seasonEpisodes.length, (
                    episodeIndex,
                  ) {
                    final episode = seasonEpisodes[episodeIndex];
                    final nextEpisode = _findNextEpisode(episodes, episode);
                    final episodeTitle =
                        'T$season E${episode.episodeNumber} - ${episode.title}';

                    return ListTile(
                      title: Text(episodeTitle),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () {
                        final nextParams = nextEpisode == null
                            ? ''
                            : '&nextId=${nextEpisode.id}&nextTitle=${Uri.encodeComponent(nextEpisode.title)}&nextExt=${nextEpisode.containerExtension ?? ''}';

                        context.push(
                          '/player?title=${Uri.encodeComponent(episodeTitle)}&id=${episode.id}&type=series&ext=${episode.containerExtension ?? ''}$nextParams',
                        );
                      },
                    );
                  }),
                ),
              );
            },
          );
        },
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
