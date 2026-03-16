import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vod_category.dart';
import '../../domain/entities/vod_stream.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final _vodRawCategoriesProvider = FutureProvider<List<VodCategory>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const <VodCategory>[];
  }

  return ref.watch(getVodCategoriesUseCaseProvider)(
        username: session.username,
        password: session.password,
      );
});

final _excludedVodCategoryIdsProvider = FutureProvider<Set<String>>((ref) async {
  final categories = await ref.watch(_vodRawCategoriesProvider.future);
  return categories
      .where((category) => _isKaraokeCategoryName(category.name))
      .map((category) => category.id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
});

final vodCategoriesProvider = FutureProvider<List<VodCategory>>((ref) async {
  final categories = await ref.watch(_vodRawCategoriesProvider.future);
  return categories
      .where((category) => !_isKaraokeCategoryName(category.name))
      .toList(growable: false);
});

final vodStreamsProvider = FutureProvider<List<VodStream>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return const <VodStream>[];
  }

  final excludedCategoryIds = await ref.watch(
    _excludedVodCategoryIdsProvider.future,
  );

  final streams = await ref.watch(getVodStreamsUseCaseProvider)(
        username: session.username,
        password: session.password,
      );

  if (excludedCategoryIds.isEmpty) {
    return streams;
  }

  return streams
      .where((stream) => !excludedCategoryIds.contains(stream.categoryId.trim()))
      .toList(growable: false);
});

bool _isKaraokeCategoryName(String name) {
  final normalized = name.toLowerCase().trim();
  return normalized.contains('karaoke');
}
