enum SearchContentType { live, vod, series }

extension SearchContentTypeX on SearchContentType {
  String get wireName {
    return switch (this) {
      SearchContentType.live => 'live',
      SearchContentType.vod => 'vod',
      SearchContentType.series => 'series',
    };
  }

  String get subtitle {
    return switch (this) {
      SearchContentType.live => 'Live TV',
      SearchContentType.vod => 'Movie',
      SearchContentType.series => 'Series',
    };
  }
}

class SearchIndexItem {
  const SearchIndexItem({
    required this.id,
    required this.title,
    required this.titleNormalized,
    required this.type,
    required this.tokens,
    required this.popularity,
    this.categoryId,
    this.extension,
    this.posterUrl,
    this.lastViewedAt,
  });

  final String id;
  final String title;
  final String titleNormalized;
  final SearchContentType type;
  final List<String> tokens;
  final int popularity;
  final String? categoryId;
  final String? extension;
  final String? posterUrl;
  final DateTime? lastViewedAt;

  String get uniqueId => '${type.wireName}:$id';

  String get playerType => type.wireName;

  SearchIndexItem copyWith({DateTime? lastViewedAt}) {
    return SearchIndexItem(
      id: id,
      title: title,
      titleNormalized: titleNormalized,
      type: type,
      tokens: tokens,
      popularity: popularity,
      categoryId: categoryId,
      extension: extension,
      posterUrl: posterUrl,
      lastViewedAt: lastViewedAt,
    );
  }
}
