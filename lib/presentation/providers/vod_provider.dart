import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vod_category.dart';
import '../../domain/entities/vod_stream.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final vodCategoriesProvider = FutureProvider<List<VodCategory>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  return ref.watch(getVodCategoriesUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});

final vodStreamsProvider = FutureProvider<List<VodStream>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const [];
  }

  return ref.watch(getVodStreamsUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});
