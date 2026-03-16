import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_stream.dart';
import '../../domain/entities/search_index_item.dart';
import '../../domain/entities/series_item.dart';
import '../../domain/entities/vod_stream.dart';
import 'app_providers.dart';
import 'library_provider.dart';
import 'live_provider.dart';
import 'parental_provider.dart';
import 'series_provider.dart';
import 'vod_provider.dart';

const int _maxSnapshotItems = 50000;
const int _searchSnapshotVersion = 3;
const int _maxGlobalRankedResults = 180;
const int _maxTypeRankedResults = 80;
const int _maxCachedPrefilterItems = 15000;
const int _searchSnapshotTtlHoursFromDefine = int.fromEnvironment(
  'SEARCH_SNAPSHOT_TTL_HOURS',
  defaultValue: 0,
);

_SearchPrefilterCacheEntry? _searchPrefilterCache;

Duration get _searchSnapshotTtl {
  if (_searchSnapshotTtlHoursFromDefine > 0) {
    return Duration(hours: _searchSnapshotTtlHoursFromDefine);
  }

  // More aggressive refresh in debug/profile while keeping production stable.
  return kReleaseMode ? const Duration(hours: 18) : const Duration(hours: 6);
}

final searchSnapshotTtlProvider = Provider<Duration>((_) {
  return _searchSnapshotTtl;
});

final searchSnapshotDebugLineProvider = Provider<String?>((ref) {
  if (!kDebugMode) {
    return null;
  }

  final storage = ref.watch(localStorageProvider);
  final meta = storage.getSearchIndexSnapshotMeta();
  final validation = _validateSnapshotMeta(meta);
  final ttlHours = ref.watch(searchSnapshotTtlProvider).inHours;

  final rawItemCount = meta?['itemCount'];
  final itemCount = rawItemCount is int
      ? rawItemCount
      : int.tryParse(rawItemCount?.toString() ?? '');

  if (validation.isValid) {
    return 'snapshot=ok age=${validation.ageMinutes}m ttl=${ttlHours}h '
        'items=${validation.itemCount ?? itemCount ?? -1}';
  }

  return 'snapshot=invalid reason=${validation.reason?.name ?? 'unknown'} '
      'ttl=${ttlHours}h';
});

final searchIndexSnapshotProvider = Provider<List<SearchIndexItem>>((ref) {
  final storage = ref.watch(localStorageProvider);
  final meta = storage.getSearchIndexSnapshotMeta();
  final validation = _validateSnapshotMeta(meta);

  if (!validation.isValid) {
    if (kDebugMode) {
      debugPrint(
        '[search_index] snapshotInvalid '
        'reason=${validation.reason?.name} '
        'version=${validation.version} expected=$_searchSnapshotVersion '
        'ttlHours=${_searchSnapshotTtl.inHours}',
      );
    }
    unawaited(storage.clearSearchIndexSnapshot());
    return const <SearchIndexItem>[];
  }

  final rows = storage.getSearchIndexSnapshot();
  if (rows.isEmpty) {
    if (kDebugMode) {
      debugPrint('[search_index] snapshotEmptyPayload -> ignoring');
    }
    return const <SearchIndexItem>[];
  }

  final items = <SearchIndexItem>[];
  for (final row in rows) {
    final item = _fromSnapshotMap(row);
    if (item == null) {
      continue;
    }
    items.add(item);
  }

  if (kDebugMode) {
    final expectedCount = validation.itemCount;
    if (expectedCount != null && expectedCount != rows.length) {
      debugPrint(
        '[search_index] snapshotCountMismatch '
        'meta=$expectedCount payload=${rows.length}',
      );
    }

    debugPrint(
      '[search_index] snapshotItems=${items.length} '
      'snapshotAgeMin=${validation.ageMinutes ?? -1}',
    );
  }

  return UnmodifiableListView<SearchIndexItem>(items);
});

final searchBaseItemsProvider = Provider<List<SearchIndexItem>>((ref) {
  final remote = ref.watch(searchIndexProvider).valueOrNull;
  if (remote != null && remote.isNotEmpty) {
    return remote;
  }
  return ref.watch(searchIndexSnapshotProvider);
});

final searchIndexProvider = FutureProvider<List<SearchIndexItem>>((ref) async {
  final stopwatch = Stopwatch()..start();
  final results = await Future.wait<dynamic>([
    ref.watch(liveStreamsProvider.future),
    ref.watch(vodStreamsProvider.future),
    ref.watch(seriesProvider.future),
  ]);

  final live = results[0] as List<LiveStream>;
  final vod = results[1] as List<VodStream>;
  final series = results[2] as List<SeriesItem>;

  final entries = <String, SearchIndexItem>{};

  for (var i = 0; i < live.length; i++) {
    final item = live[i];
    final title = item.name.trim();
    if (title.isEmpty || item.id.isEmpty) {
      continue;
    }
    final normalized = _normalize(title);
    final indexed = SearchIndexItem(
      id: item.id,
      title: title,
      titleNormalized: normalized,
      type: SearchContentType.live,
      categoryId: item.categoryId,
      extension: null,
      posterUrl: null,
      popularity: live.length - i,
      tokens: _tokens(normalized),
    );
    entries[indexed.uniqueId] = indexed;
  }

  for (var i = 0; i < vod.length; i++) {
    final item = vod[i];
    final title = item.name.trim();
    if (title.isEmpty || item.id.isEmpty) {
      continue;
    }
    final normalized = _normalize(title);
    final indexed = SearchIndexItem(
      id: item.id,
      title: title,
      titleNormalized: normalized,
      type: SearchContentType.vod,
      categoryId: item.categoryId,
      extension: item.containerExtension,
      posterUrl: _sanitizePosterUrl(item.coverUrl),
      popularity: vod.length - i,
      tokens: _tokens(normalized),
    );
    entries[indexed.uniqueId] = indexed;
  }

  for (var i = 0; i < series.length; i++) {
    final item = series[i];
    final title = item.name.trim();
    if (title.isEmpty || item.id.isEmpty) {
      continue;
    }
    final normalized = _normalize(title);
    final indexed = SearchIndexItem(
      id: item.id,
      title: title,
      titleNormalized: normalized,
      type: SearchContentType.series,
      categoryId: item.categoryId,
      extension: null,
      posterUrl: _sanitizePosterUrl(item.coverUrl),
      popularity: series.length - i,
      tokens: _tokens(normalized),
    );
    entries[indexed.uniqueId] = indexed;
  }

  final dedupedEntries = _dedupeSearchEntries(entries.values);

  if (kDebugMode) {
    debugPrint(
      '[search_index] items=${dedupedEntries.length} '
      'live=${live.length} vod=${vod.length} series=${series.length} '
      'buildMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  final snapshot = dedupedEntries
      .take(_maxSnapshotItems)
      .map(_toSnapshotMap)
      .toList(growable: false);
  await ref
      .read(localStorageProvider)
      .saveSearchIndexSnapshot(snapshot, version: _searchSnapshotVersion);
  ref.invalidate(searchIndexSnapshotProvider);

  return UnmodifiableListView<SearchIndexItem>(
    dedupedEntries,
  );
});

final searchRankedItemsProvider =
    Provider.family<List<SearchIndexItem>, String>((ref, rawQuery) {
      final baseItems = ref.watch(searchBaseItemsProvider);
      final parental = ref.watch(parentalProvider);
      final history = ref.watch(historyItemsProvider);

      if (baseItems.isEmpty) {
        return const <SearchIndexItem>[];
      }

      final historyRank = <String, int>{};
      final historyLastViewedAt = <String, DateTime>{};
      for (var i = 0; i < history.length; i++) {
        final row = history[i];
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }

        final rawType = row['type']?.toString();
        final type = _parseType(rawType);
        final key = '${type.wireName}:$id';
        historyRank[key] = i;

        final updatedAtRaw = row['updatedAt']?.toString();
        final updatedAt = DateTime.tryParse(updatedAtRaw ?? '');
        if (updatedAt != null) {
          historyLastViewedAt[key] = updatedAt;
        }
      }

      final query = _normalize(rawQuery);
      final queryTokens = _tokens(query);
      final baseVersion = _baseVersion(baseItems);

      var sourceItems = baseItems;
      final cached = _searchPrefilterCache;
      if (query.isNotEmpty &&
          cached != null &&
          cached.baseVersion == baseVersion &&
          cached.query.isNotEmpty &&
          query.startsWith(cached.query)) {
        sourceItems = cached.items;
      }

      final prefiltered = query.isEmpty
          ? sourceItems
          : _prefilterItems(
              items: sourceItems,
              query: query,
              queryTokens: queryTokens,
            );

      if (query.isEmpty || prefiltered.length > _maxCachedPrefilterItems) {
        _searchPrefilterCache = null;
      } else {
        _searchPrefilterCache = _SearchPrefilterCacheEntry(
          baseVersion: baseVersion,
          query: query,
          items: prefiltered,
        );
      }

      final enriched = <SearchIndexItem>[];
      for (final item in prefiltered) {
        if (parental.enabled && _isAdultContent(item.titleNormalized)) {
          continue;
        }

        final key = item.uniqueId;
        final lastViewedAt = historyLastViewedAt[key];
        enriched.add(item.copyWith(lastViewedAt: lastViewedAt));
      }

      final globalTop = <_ScoredItem>[];
      final liveTop = <_ScoredItem>[];
      final vodTop = <_ScoredItem>[];
      final seriesTop = <_ScoredItem>[];

      for (final item in enriched) {
        final score = _score(
          item: item,
          query: query,
          queryTokens: queryTokens,
          historyRank: historyRank[item.uniqueId],
        );

        if (query.isNotEmpty && score <= 0) {
          continue;
        }

        final scored = _ScoredItem(item: item, score: score);
        _insertBoundedRanked(globalTop, scored, _maxGlobalRankedResults);

        switch (item.type) {
          case SearchContentType.live:
            _insertBoundedRanked(liveTop, scored, _maxTypeRankedResults);
          case SearchContentType.vod:
            _insertBoundedRanked(vodTop, scored, _maxTypeRankedResults);
          case SearchContentType.series:
            _insertBoundedRanked(seriesTop, scored, _maxTypeRankedResults);
        }
      }

      final merged = <String, _ScoredItem>{};
      void absorb(List<_ScoredItem> source) {
        for (final entry in source) {
          merged[entry.item.uniqueId] = entry;
        }
      }

      absorb(globalTop);
      absorb(liveTop);
      absorb(vodTop);
      absorb(seriesTop);

      final ranked = merged.values.toList(growable: false)
        ..sort(_compareScored);

      if (kDebugMode && query.isNotEmpty) {
        debugPrint(
          '[search_query] query="$query" results=${ranked.length} '
          'source=${sourceItems.length} prefiltered=${prefiltered.length}',
        );
      }

      return ranked.map((e) => e.item).toList(growable: false);
    });

int _score({
  required SearchIndexItem item,
  required String query,
  required List<String> queryTokens,
  required int? historyRank,
}) {
  var score = 0;

  if (query.isEmpty) {
    score += _historyBoost(historyRank);
    score += _recencyBoost(item.lastViewedAt);
    score += _popularityBoost(item.popularity);
    return score;
  }

  final title = item.titleNormalized;
  if (title.startsWith(query)) {
    score += 140;
  } else if (title.contains(query)) {
    score += 90;
  }

  for (final queryToken in queryTokens) {
    if (queryToken.isEmpty) {
      continue;
    }

    for (final token in item.tokens) {
      if (token == queryToken) {
        score += 45;
      } else if (token.startsWith(queryToken)) {
        score += 28;
      } else if (token.contains(queryToken)) {
        score += 12;
      }
    }
  }

  score += _historyBoost(historyRank);
  score += _recencyBoost(item.lastViewedAt);
  score += _popularityBoost(item.popularity);
  return score;
}

int _historyBoost(int? historyRank) {
  if (historyRank == null) {
    return 0;
  }
  final clamped = historyRank.clamp(0, 20);
  return 50 - (clamped * 2);
}

int _recencyBoost(DateTime? lastViewedAt) {
  if (lastViewedAt == null) {
    return 0;
  }

  final ageInDays = DateTime.now().difference(lastViewedAt).inDays;
  if (ageInDays <= 0) {
    return 26;
  }
  if (ageInDays <= 3) {
    return 20;
  }
  if (ageInDays <= 7) {
    return 14;
  }
  if (ageInDays <= 14) {
    return 8;
  }
  return 2;
}

int _popularityBoost(int popularity) {
  if (popularity <= 0) {
    return 0;
  }
  return (popularity ~/ 250).clamp(0, 20);
}

SearchContentType _parseType(String? value) {
  return switch (value) {
    'vod' => SearchContentType.vod,
    'series' => SearchContentType.series,
    _ => SearchContentType.live,
  };
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _tokens(String value) {
  if (value.isEmpty) {
    return const <String>[];
  }

  return value
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

bool _isAdultContent(String titleNormalized) {
  return titleNormalized.contains('adult') ||
      titleNormalized.contains('xxx') ||
      titleNormalized.contains('+18');
}

class _ScoredItem {
  const _ScoredItem({required this.item, required this.score});

  final SearchIndexItem item;
  final int score;
}

class _SearchPrefilterCacheEntry {
  const _SearchPrefilterCacheEntry({
    required this.baseVersion,
    required this.query,
    required this.items,
  });

  final int baseVersion;
  final String query;
  final List<SearchIndexItem> items;
}

List<SearchIndexItem> _prefilterItems({
  required List<SearchIndexItem> items,
  required String query,
  required List<String> queryTokens,
}) {
  final results = <SearchIndexItem>[];

  for (final item in items) {
    final title = item.titleNormalized;
    if (title.startsWith(query) || title.contains(query)) {
      results.add(item);
      continue;
    }

    if (queryTokens.isEmpty) {
      continue;
    }

    var allTokensMatch = true;
    for (final queryToken in queryTokens) {
      if (queryToken.isEmpty) {
        continue;
      }

      var tokenMatched = false;
      for (final token in item.tokens) {
        if (token.startsWith(queryToken) || token.contains(queryToken)) {
          tokenMatched = true;
          break;
        }
      }

      if (!tokenMatched) {
        allTokensMatch = false;
        break;
      }
    }

    if (allTokensMatch) {
      results.add(item);
    }
  }

  return results;
}

void _insertBoundedRanked(
  List<_ScoredItem> target,
  _ScoredItem next,
  int maxItems,
) {
  if (maxItems <= 0) {
    return;
  }

  if (target.isNotEmpty &&
      target.length >= maxItems &&
      _compareScored(next, target.last) >= 0) {
    return;
  }

  var insertAt = target.length;
  while (insertAt > 0 && _compareScored(next, target[insertAt - 1]) < 0) {
    insertAt--;
  }

  target.insert(insertAt, next);
  if (target.length > maxItems) {
    target.removeLast();
  }
}

int _compareScored(_ScoredItem a, _ScoredItem b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) {
    return byScore;
  }

  final byViewed =
      (b.item.lastViewedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.item.lastViewedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
  if (byViewed != 0) {
    return byViewed;
  }

  return a.item.title.compareTo(b.item.title);
}

int _baseVersion(List<SearchIndexItem> items) {
  if (items.isEmpty) {
    return 0;
  }

  final mid = items[items.length ~/ 2].uniqueId;
  return Object.hash(
    items.length,
    items.first.uniqueId,
    mid,
    items.last.uniqueId,
  );
}

List<SearchIndexItem> _dedupeSearchEntries(Iterable<SearchIndexItem> items) {
  final deduped = <String, SearchIndexItem>{};

  for (final item in items) {
    final key = _dedupeKey(item);
    final current = deduped[key];
    if (current == null || _isBetterDedupCandidate(current, item)) {
      deduped[key] = item;
    }
  }

  return deduped.values.toList(growable: false);
}

String _dedupeKey(SearchIndexItem item) {
  // Keep live channels unique by id; for VOD/series collapse title variants.
  if (item.type == SearchContentType.live) {
    return item.uniqueId;
  }
  return '${item.type.wireName}:${item.titleNormalized}';
}

bool _isBetterDedupCandidate(SearchIndexItem current, SearchIndexItem next) {
  final byPoster = _hasPoster(next.posterUrl).compareTo(
    _hasPoster(current.posterUrl),
  );
  if (byPoster != 0) {
    return byPoster > 0;
  }

  final byExtension = _extensionRank(next.extension)
      .compareTo(_extensionRank(current.extension));
  if (byExtension != 0) {
    return byExtension > 0;
  }

  final byPopularity = next.popularity.compareTo(current.popularity);
  if (byPopularity != 0) {
    return byPopularity > 0;
  }

  final byId = next.id.compareTo(current.id);
  return byId < 0;
}

int _hasPoster(String? posterUrl) {
  final value = posterUrl?.trim() ?? '';
  return value.isEmpty ? 0 : 1;
}

int _extensionRank(String? extension) {
  final normalized = (extension ?? '').trim().toLowerCase();
  return switch (normalized) {
    'mkv' => 4,
    'mp4' => 3,
    'avi' => 2,
    '' => 0,
    _ => 1,
  };
}

class _SnapshotValidationResult {
  const _SnapshotValidationResult.valid({
    required this.version,
    required this.ageMinutes,
    required this.itemCount,
  }) : isValid = true,
       reason = null;

  const _SnapshotValidationResult.invalid({
    required this.reason,
    required this.version,
    required this.itemCount,
  }) : isValid = false,
       ageMinutes = null;

  final bool isValid;
  final _SnapshotInvalidReason? reason;
  final int? version;
  final int? ageMinutes;
  final int? itemCount;
}

enum _SnapshotInvalidReason {
  metaMissing,
  versionMissing,
  versionMismatch,
  updatedAtMissing,
  updatedAtInvalid,
  expired,
}

_SnapshotValidationResult _validateSnapshotMeta(Map<String, dynamic>? meta) {
  if (meta == null) {
    return const _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.metaMissing,
      version: null,
      itemCount: null,
    );
  }

  final rawVersion = meta['version'];
  final version = rawVersion is int
      ? rawVersion
      : int.tryParse(rawVersion?.toString() ?? '');
  final rawItemCount = meta['itemCount'];
  final itemCount = rawItemCount is int
      ? rawItemCount
      : int.tryParse(rawItemCount?.toString() ?? '');

  if (version == null) {
    return _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.versionMissing,
      version: null,
      itemCount: itemCount,
    );
  }

  if (version != _searchSnapshotVersion) {
    return _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.versionMismatch,
      version: version,
      itemCount: itemCount,
    );
  }

  final rawUpdatedAt = meta['updatedAt']?.toString();
  if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) {
    return _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.updatedAtMissing,
      version: version,
      itemCount: itemCount,
    );
  }

  final updatedAt = DateTime.tryParse(rawUpdatedAt);
  if (updatedAt == null) {
    return _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.updatedAtInvalid,
      version: version,
      itemCount: itemCount,
    );
  }

  final snapshotAge = DateTime.now().difference(updatedAt);
  if (snapshotAge > _searchSnapshotTtl) {
    return _SnapshotValidationResult.invalid(
      reason: _SnapshotInvalidReason.expired,
      version: version,
      itemCount: itemCount,
    );
  }

  return _SnapshotValidationResult.valid(
    version: version,
    ageMinutes: snapshotAge.inMinutes,
    itemCount: itemCount,
  );
}

Map<String, dynamic> _toSnapshotMap(SearchIndexItem item) {
  return <String, dynamic>{
    'i': item.id,
    't': item.title,
    'n': item.titleNormalized,
    'y': item.type.wireName,
    'c': item.categoryId,
    'e': item.extension,
    'u': item.posterUrl,
    'p': item.popularity,
  };
}

SearchIndexItem? _fromSnapshotMap(Map<String, dynamic> row) {
  final id = row['i']?.toString() ?? '';
  final title = row['t']?.toString() ?? '';
  final normalized = row['n']?.toString() ?? '';
  final typeRaw = row['y']?.toString();
  final popularityRaw = row['p'];

  if (id.isEmpty || title.isEmpty || normalized.isEmpty) {
    return null;
  }

  final type = _parseType(typeRaw);
  final popularity = popularityRaw is int
      ? popularityRaw
      : int.tryParse(popularityRaw?.toString() ?? '') ?? 0;

  return SearchIndexItem(
    id: id,
    title: title,
    titleNormalized: normalized,
    type: type,
    categoryId: row['c']?.toString(),
    extension: row['e']?.toString(),
    posterUrl: _sanitizePosterUrl(row['u']?.toString()),
    popularity: popularity,
    tokens: _tokens(normalized),
  );
}

String? _sanitizePosterUrl(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  return trimmed;
}
