import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/series_episode.dart';
import '../../domain/entities/series_item.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final seriesProvider = FutureProvider<List<SeriesItem>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  return ref.watch(getSeriesUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});

final seriesEpisodesProvider = FutureProvider.family<List<SeriesEpisode>, String>((ref, seriesId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null || seriesId.isEmpty) {
    return const [];
  }

  return ref.watch(getSeriesInfoUseCaseProvider)(
        username: session.username,
        password: session.password,
        seriesId: seriesId,
      );
});
