import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_category.dart';
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
