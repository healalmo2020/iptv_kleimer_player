import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_category.dart';
import '../../domain/entities/epg_event.dart';
import '../../domain/entities/live_stream.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final _liveStreamsCacheProvider =
    StateNotifierProvider<_LiveStreamsCacheNotifier, Map<String, _LiveStreamsCacheEntry>>(
      (_) => _LiveStreamsCacheNotifier(),
    );

const Duration _liveStreamsCacheTtl = Duration(minutes: 8);

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

final liveStreamsByCategoryProvider =
    FutureProvider.family<List<LiveStream>, String?>((ref, categoryId) async {
      final session = ref.watch(authControllerProvider).valueOrNull;
      if (session == null) {
        return const [];
      }

      final normalizedCategoryId = categoryId?.trim();
      if (normalizedCategoryId == null || normalizedCategoryId.isEmpty) {
        return const [];
      }

      final cacheKey =
          '${session.username}:${session.password}:$normalizedCategoryId';
      final cache = ref.watch(_liveStreamsCacheProvider);
      final cached = cache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.updatedAt) <= _liveStreamsCacheTtl) {
        return cached.items;
      }

      final items = await ref.watch(getLiveStreamsUseCaseProvider)(
            username: session.username,
            password: session.password,
            categoryId: normalizedCategoryId,
          );

      ref
          .read(_liveStreamsCacheProvider.notifier)
          .set(cacheKey, items, updatedAt: DateTime.now());

      return items;
    });

class _LiveStreamsCacheNotifier
    extends StateNotifier<Map<String, _LiveStreamsCacheEntry>> {
  _LiveStreamsCacheNotifier() : super(const {});

  void set(String key, List<LiveStream> items, {required DateTime updatedAt}) {
    final next = Map<String, _LiveStreamsCacheEntry>.from(state)
      ..removeWhere(
        (_, value) =>
            updatedAt.difference(value.updatedAt) > _liveStreamsCacheTtl,
      )
      ..[key] = _LiveStreamsCacheEntry(
        items: List<LiveStream>.unmodifiable(items),
        updatedAt: updatedAt,
      );
    state = next;
  }
}

class _LiveStreamsCacheEntry {
  const _LiveStreamsCacheEntry({required this.items, required this.updatedAt});

  final List<LiveStream> items;
  final DateTime updatedAt;
}

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
