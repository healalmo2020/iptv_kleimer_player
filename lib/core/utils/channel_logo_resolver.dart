String resolveChannelLogoUrl({
  required String channelName,
  String? primaryIconUrl,
}) {
  final primary = primaryIconUrl?.trim();
  if (primary != null && primary.isNotEmpty) {
    return primary;
  }

  final key = _normalizeChannelName(channelName);
  final path = _logoPathByChannelKey[key];
  if (path == null) {
    final inferredPath = _inferLogoPathByKey(key);
    if (inferredPath == null) {
      return '';
    }
    return 'https://raw.githubusercontent.com/tv-logo/tv-logos/main/$inferredPath';
  }

  return 'https://raw.githubusercontent.com/tv-logo/tv-logos/main/$path';
}

String _normalizeChannelName(String value) {
  var result = value.toLowerCase().trim();

  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    '&': ' and ',
  };

  replacements.forEach((from, to) {
    result = result.replaceAll(from, to);
  });

  result = result
      .replaceAll(RegExp(r'\b(hd|fhd|uhd|4k|sd|latam|la|mx|es|us)\b'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return result.replaceAll(' ', '');
}

const Map<String, String> _logoPathByChannelKey = {
  'espn': 'countries/united-states/espn-us.png',
  'espn2': 'countries/united-states/espn-2-us.png',
  'discoverychannel': 'countries/united-states/discovery-channel-us.png',
  'cartoonnetwork': 'countries/united-states/cartoon-network-us.png',
  'hbo': 'countries/united-states/hbo-us.png',
  'cnn': 'countries/united-states/cnn-us.png',
  'foxnews': 'countries/united-states/fox-news-us.png',
  'univision': 'countries/united-states/univision-us.png',
  'azteca7': 'countries/mexico/azteca-7-mx.png',
  'canal5': 'countries/mexico/canal-5-mx.png',
  'lasestrellas': 'countries/mexico/las-estrellas-mx.png',
  'antena3': 'countries/spain/antena-3-es.png',
};

String? _inferLogoPathByKey(String key) {
  for (final matcher in _keywordLogoMatchers) {
    if (key.contains(matcher.keyword)) {
      return matcher.path;
    }
  }
  return null;
}

const List<_KeywordLogoMatcher> _keywordLogoMatchers = [
  _KeywordLogoMatcher('lasestrellas', 'countries/mexico/las-estrellas-mx.png'),
  _KeywordLogoMatcher('estrellas', 'countries/mexico/las-estrellas-mx.png'),
  _KeywordLogoMatcher('azteca7', 'countries/mexico/azteca-7-mx.png'),
  _KeywordLogoMatcher('canal5', 'countries/mexico/canal-5-mx.png'),
  _KeywordLogoMatcher('espn2', 'countries/united-states/espn-2-us.png'),
  _KeywordLogoMatcher('espn', 'countries/united-states/espn-us.png'),
  _KeywordLogoMatcher(
    'foxsports2',
    'countries/united-states/fox-sports-2-us.png',
  ),
  _KeywordLogoMatcher(
    'foxsports1',
    'countries/united-states/fox-sports-1-us.png',
  ),
  _KeywordLogoMatcher('foxone', 'countries/united-states/fox-sports-1-us.png'),
  _KeywordLogoMatcher('foxnews', 'countries/united-states/fox-news-us.png'),
  _KeywordLogoMatcher(
    'weatherchannel',
    'countries/united-states/weather-channel-us.png',
  ),
  _KeywordLogoMatcher(
    'bbcworld',
    'countries/united-kingdom/bbc-world-news-uk.png',
  ),
  _KeywordLogoMatcher('bbcnews', 'countries/united-kingdom/bbc-news-hz-uk.png'),
  _KeywordLogoMatcher('cnn', 'countries/united-states/cnn-us.png'),
  _KeywordLogoMatcher(
    'discovery',
    'countries/united-states/discovery-channel-us.png',
  ),
  _KeywordLogoMatcher(
    'cartoonnetwork',
    'countries/united-states/cartoon-network-us.png',
  ),
  _KeywordLogoMatcher('univision', 'countries/united-states/univision-us.png'),
  _KeywordLogoMatcher('hbo', 'countries/united-states/hbo-us.png'),
  _KeywordLogoMatcher('tnt', 'countries/united-states/tnt-us.png'),
  _KeywordLogoMatcher('nbc', 'countries/united-states/nbc-us.png'),
  _KeywordLogoMatcher('abc', 'countries/united-states/abc-us.png'),
  _KeywordLogoMatcher('cbs', 'countries/united-states/cbs-news-us.png'),
  _KeywordLogoMatcher('fox', 'countries/united-states/fox-us.png'),
];

class _KeywordLogoMatcher {
  const _KeywordLogoMatcher(this.keyword, this.path);

  final String keyword;
  final String path;
}
