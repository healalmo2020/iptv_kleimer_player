String resolveChannelLogoUrl({
  required String channelName,
  String? primaryIconUrl,
}) {
  final primary = primaryIconUrl?.trim();
  if (primary != null && primary.isNotEmpty) {
    return primary;
  }

  return resolveChannelLogoRepositoryUrl(channelName: channelName);
}

String resolveChannelLogoRepositoryUrl({required String channelName}) {
  final key = _normalizeChannelName(channelName);
  final path = _logoPathByChannelKey[key];
  if (path == null) {
    final inferredPath = _inferLogoPathByKey(key);
    if (inferredPath == null) {
      return '';
    }
    return '$_logoRepositoryBaseUrl/$inferredPath';
  }

  return '$_logoRepositoryBaseUrl/$path';
}

const String _logoRepositoryBaseUrl =
    'https://cdn.jsdelivr.net/gh/tv-logo/tv-logos@main';

String _normalizeChannelName(String value) {
  var result = value.toLowerCase().trim();

  if (result.contains('|')) {
    final segments = result
        .split('|')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isNotEmpty) {
      result = segments.last;
    }
  }

  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    '&': ' and ',
    '+': ' plus ',
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
  'aande': 'countries/united-states/a-and-e-us.png',
  'amas': 'countries/mexico/a-mas-mx.png',
  'aplus': 'countries/mexico/a-mas-mx.png',
  'amc': 'countries/united-states/amc-us.png',
  'animalplanet': 'countries/united-states/animal-planet-us.png',
  'axn': 'countries/spain/axn-es.png',
  'adrenalina': 'countries/mexico/adrenalina-sports-network-mx.png',
  'aztecaclic': 'countries/mexico/azteca-clic-mx.png',
  'aztecacinema': 'countries/world-latin-america/azteca-cinema-lam.png',
  'aztecacorazon': 'countries/mexico/corazon-mx.png',
  'a3series': 'countries/spain/atreseries-es.png',
  'a3seriesint': 'countries/spain/atreseries-es.png',
  'forotv': 'countries/mexico/n-plus-foro-mx.png',
  'nplusforo': 'countries/mexico/n-plus-foro-mx.png',
  'nmas': 'countries/mexico/n-mas-mx.png',
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
  _KeywordLogoMatcher('aande', 'countries/united-states/a-and-e-us.png'),
  _KeywordLogoMatcher('aplus', 'countries/mexico/a-mas-mx.png'),
  _KeywordLogoMatcher('amas', 'countries/mexico/a-mas-mx.png'),
  _KeywordLogoMatcher('amc', 'countries/united-states/amc-us.png'),
  _KeywordLogoMatcher(
    'animalplanet',
    'countries/united-states/animal-planet-us.png',
  ),
  _KeywordLogoMatcher(
    'adrenalina',
    'countries/mexico/adrenalina-sports-network-mx.png',
  ),
  _KeywordLogoMatcher('axn', 'countries/spain/axn-es.png'),
  _KeywordLogoMatcher('aztecaclic', 'countries/mexico/azteca-clic-mx.png'),
  _KeywordLogoMatcher(
    'aztecacinema',
    'countries/world-latin-america/azteca-cinema-lam.png',
  ),
  _KeywordLogoMatcher('corazon', 'countries/mexico/corazon-mx.png'),
  _KeywordLogoMatcher('a3series', 'countries/spain/atreseries-es.png'),
  _KeywordLogoMatcher('nplusforo', 'countries/mexico/n-plus-foro-mx.png'),
  _KeywordLogoMatcher('nmas', 'countries/mexico/n-mas-mx.png'),
  _KeywordLogoMatcher('canaldelasestrellas', 'countries/mexico/las-estrellas-mx.png'),
  _KeywordLogoMatcher('elnueve', 'countries/mexico/canal-9-mx.png'),
  _KeywordLogoMatcher('forotv', 'countries/mexico/n-plus-foro-mx.png'),
  _KeywordLogoMatcher('imagen', 'countries/mexico/imagen-television-mx.png'),
  _KeywordLogoMatcher('tvazteca', 'countries/mexico/azteca-uno-mx.png'),
  _KeywordLogoMatcher('aztecauno', 'countries/mexico/azteca-uno-mx.png'),
  _KeywordLogoMatcher('azteca1', 'countries/mexico/azteca-uno-mx.png'),
  _KeywordLogoMatcher('azteca13', 'countries/mexico/azteca-uno-mx.png'),
  _KeywordLogoMatcher('canal7', 'countries/mexico/azteca-7-mx.png'),
  _KeywordLogoMatcher('adn40', 'countries/mexico/adn-noticias-mx.png'),
  _KeywordLogoMatcher('unicable', 'countries/mexico/unicable-mx.png'),
  _KeywordLogoMatcher('telemundo', 'countries/united-states/telemundo-us.png'),
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
