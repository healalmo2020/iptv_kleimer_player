import 'package:flutter/foundation.dart';

String resolveChannelLogoUrl({
  required String channelName,
  String? primaryIconUrl,
  Map<String, Map<String, String>>? jsonIndex,
  String? country,
}) {
  // 1. Try Country-Specific Search (Highest Accuracy)
  if (jsonIndex != null && jsonIndex.isNotEmpty) {
     final countryKey = country != null ? _normalizeCountryForLookup(country) : null;
     final searchKey = _normalizeForJsonLookup(channelName);

     if (kDebugMode && (channelName.toLowerCase().contains('chtv') || channelName.toLowerCase().contains('hch'))) {
        print('[LOGO-RESOLVER] Debugging channel: "$channelName"');
        print('[LOGO-RESOLVER] -> Generated Search Key: "$searchKey"');
        print('[LOGO-RESOLVER] -> Target Country Key: "$countryKey"');
        if (countryKey != null) {
          print('[LOGO-RESOLVER] -> Country In Index: ${jsonIndex.containsKey(countryKey)}');
          if (jsonIndex.containsKey(countryKey)) {
             print('[LOGO-RESOLVER] -> Sample Keys in Country Map: ${jsonIndex[countryKey]!.keys.take(5).toList()}');
          }
        }
     }

     if (countryKey != null) {
        final Map<String, String>? countryMap = jsonIndex[countryKey] ?? jsonIndex[_countryToIso(countryKey)];
        
        if (countryMap != null) {
          // Layer 1: Exact Match in Country
          if (countryMap.containsKey(searchKey)) return countryMap[searchKey]!;

          // Layer 2: Fuzzy Match in Country
          for (final entry in countryMap.entries) {
            final jsonKey = entry.key;
            if (searchKey.length > 2 && (jsonKey.contains(searchKey) || searchKey.contains(jsonKey))) {
              return entry.value;
            }
          }
        }
     }

     // 2. GLOBAL FALLBACK
     for (final countryEntry in jsonIndex.entries) {
       final map = countryEntry.value;
       if (map.containsKey(searchKey)) return map[searchKey]!;

       if (searchKey.length > 3) {
         for (final entry in map.entries) {
           final jk = entry.key;
           if (jk.contains(searchKey) || searchKey.contains(jk)) return entry.value;
         }
       }
     }

     // 3. AT-ANY-COST GLOBAL FALLBACK
     final atAnyCostKey = _normalizeForAtAnyCostLookup(channelName);
     if (atAnyCostKey.isNotEmpty && atAnyCostKey.length > 2) {
       for (final countryEntry in jsonIndex.entries) {
         final map = countryEntry.value;
         for (final entry in map.entries) {
           if (entry.key == atAnyCostKey || entry.key.contains(atAnyCostKey) || atAnyCostKey.contains(entry.key)) {
             return entry.value;
           }
         }
       }
     }
  }

  // 4. Fall back to server-provided icon URL
  final primary = primaryIconUrl?.trim();
  if (primary != null && primary.isNotEmpty) {
    return primary;
  }

  // 5. Final fallback to existing manual repository
  return resolveChannelLogoRepositoryUrl(channelName: channelName);
}

String _normalizeCountryForLookup(String country) {
  return country.toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '') // Only letters for country
      .trim();
}

String _countryToIso(String country) {
  const map = {
    'honduras': 'hn',
    'mexico': 'mx',
    'spain': 'es',
    'unitedstates': 'us',
    'argentina': 'ar',
    'colombia': 'co',
    'chile': 'cl',
    'peru': 'pe',
  };
  return map[country] ?? country;
}

String _sharedNormalize(String name) {
  if (name.isEmpty) return '';
  var n = name.toLowerCase();

  // 1. Remove common IPTV prefixes/separators (| , : , / , - , \ )
  final parts = n.split(RegExp(r'[|:/\-\\]'));
  if (parts.length > 1) {
    n = parts.last.trim();
  }

  // 2. Remove common country identifiers at the START (word boundary)
  n = n.replaceFirst(RegExp(r'^(hon|hnd|hn|es|esp|mx|mex|us|usa|latam|latino|televicentro|tvc|canal|tv)\b'), '');

  // 3. Remove common quality noise
  n = n.replaceAll(RegExp(r'\b(hd|fhd|uhd|4k|sd|1080p|720p|h264|h265|intl|latin|latam|plus|extra)\b'), ' ');

  // 4. Remove country extensions at the end (common in JSON)
  n = n.replaceFirst(RegExp(r'\.(hn|mx|es|us|ar|co|cl|pe|uy|ve|ec|bo|pa|do|ca|uk|br|pt|de|fr|gr|it)$'), '');

  // 5. Final cleaning: keep letters and numbers only, remove spaces
  return n.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
}

String _normalizeForAtAnyCostLookup(String name) {
  if (name.isEmpty) return '';
  var n = name.toLowerCase();
  // Most aggressive cleanup: only letters and numbers, ignore everything else
  return n.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
}

String _normalizeForJsonLookup(String name) => _sharedNormalize(name);

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
      .replaceAll(
        RegExp(
          r'\b(hd|fhd|uhd|4k|sd|latam|latino|latinos|la|mx|es|us|pr|ar|br|cl|co|pe|uy|ve|ec|bo|pa|do|int|intl|international)\b',
        ),
        ' ',
      )
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
  'aztecadeportes': 'countries/world-latin-america/azteca-international-lam.png',
  'aztecacinema': 'countries/world-latin-america/azteca-cinema-lam.png',
  'aztecacorazon': 'countries/mexico/corazon-mx.png',
  'a3series': 'countries/spain/atreseries-es.png',
  'a3seriesint': 'countries/spain/atreseries-es.png',
  'forotv': 'countries/mexico/n-plus-foro-mx.png',
  'bandamax': 'countries/mexico/bandamax-mx.png',
  'bitme': 'countries/mexico/bitme-mx.png',
  'canal22': 'countries/mexico/canal-22-mx.png',
  'canalonce': 'countries/mexico/canal-once-mx.png',
  'babytv': 'countries/united-states/baby-tv-us.png',
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
  'antena3int': 'countries/spain/antena-3-es.png',
  'comedycentral': 'countries/argentina/comedy-central-ar.png',
  'discoveryhomeandhealth':
      'countries/world-latin-america/discovery-home-and-health-lam.png',
  'eentertainment': 'countries/united-states/e-entertainment-us.png',
  'eentertaiment': 'countries/united-states/e-entertainment-us.png',
  'elgourmet': 'countries/world-latin-america/el-gourmet-lam.png',
  'foodnetwork': 'countries/argentina/food-network-ar.png',
  'galavision': 'countries/united-states/galavision-us.png',
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
  _KeywordLogoMatcher('bandamax', 'countries/mexico/bandamax-mx.png'),
  _KeywordLogoMatcher('bitme', 'countries/mexico/bitme-mx.png'),
  _KeywordLogoMatcher('canal22', 'countries/mexico/canal-22-mx.png'),
  _KeywordLogoMatcher('canalonce', 'countries/mexico/canal-once-mx.png'),
  _KeywordLogoMatcher('babytv', 'countries/united-states/baby-tv-us.png'),
  _KeywordLogoMatcher('axn', 'countries/spain/axn-es.png'),
  _KeywordLogoMatcher('aztecaclic', 'countries/mexico/azteca-clic-mx.png'),
  _KeywordLogoMatcher(
    'aztecacinema',
    'countries/world-latin-america/azteca-cinema-lam.png',
  ),
  _KeywordLogoMatcher(
    'aztecadeportes',
    'countries/world-latin-america/azteca-international-lam.png',
  ),
  _KeywordLogoMatcher('corazon', 'countries/mexico/corazon-mx.png'),
  _KeywordLogoMatcher('a3series', 'countries/spain/atreseries-es.png'),
  _KeywordLogoMatcher('nplusforo', 'countries/mexico/n-plus-foro-mx.png'),
  _KeywordLogoMatcher('nmas', 'countries/mexico/n-mas-mx.png'),
  _KeywordLogoMatcher('canaldelasestrellas', 'countries/mexico/las-estrellas-mx.png'),
  _KeywordLogoMatcher('elnueve', 'countries/mexico/canal-9-mx.png'),
  _KeywordLogoMatcher('forotv', 'countries/mexico/n-plus-foro-mx.png'),
  _KeywordLogoMatcher('antena3int', 'countries/spain/antena-3-es.png'),
  _KeywordLogoMatcher('antena3', 'countries/spain/antena-3-es.png'),
  _KeywordLogoMatcher('comedycentral', 'countries/argentina/comedy-central-ar.png'),
  _KeywordLogoMatcher(
    'discoveryhomeandhealth',
    'countries/world-latin-america/discovery-home-and-health-lam.png',
  ),
  _KeywordLogoMatcher(
    'discoveryhomehealth',
    'countries/world-latin-america/discovery-home-and-health-lam.png',
  ),
  _KeywordLogoMatcher('eentertainment', 'countries/united-states/e-entertainment-us.png'),
  _KeywordLogoMatcher('eentertaiment', 'countries/united-states/e-entertainment-us.png'),
  _KeywordLogoMatcher('elgourmet', 'countries/world-latin-america/el-gourmet-lam.png'),
  _KeywordLogoMatcher('foodnetwork', 'countries/argentina/food-network-ar.png'),
  _KeywordLogoMatcher('galavision', 'countries/united-states/galavision-us.png'),
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
