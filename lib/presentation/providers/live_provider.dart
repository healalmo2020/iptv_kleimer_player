import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_category.dart';
import '../../domain/entities/epg_event.dart';
import '../../domain/entities/live_stream.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final liveCategoriesProvider = FutureProvider<List<LiveCategory>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  return ref.watch(getLiveCategoriesUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});

final liveStreamsProvider = FutureProvider<List<LiveStream>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  return ref.watch(getLiveStreamsUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});

final liveEpgProvider = FutureProvider.family<List<EpgEvent>, String>((ref, streamId) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null || streamId.isEmpty) {
    return const [];
  }

  return ref.watch(getLiveEpgUseCaseProvider)(
        username: session.username,
        password: session.password,
        streamId: streamId,
      );
});
