import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/json_logo_item.dart';

final logoResolverProvider = StateNotifierProvider<LogoResolverNotifier, Map<String, Map<String, String>>>((ref) {
  return LogoResolverNotifier();
});

class LogoResolverNotifier extends StateNotifier<Map<String, Map<String, String>>> {
  LogoResolverNotifier() : super({}) {
    loadLogos();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadLogos() async {
    if (_isLoading) return;
    _isLoading = true;

    if (kDebugMode) print('LogoResolver: Starting to load logos...');

    try {
      // 1. Find all logo assets
      List<String> logoPaths = [];
      try {
        final String manifestContent = await rootBundle.loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        logoPaths = manifestMap.keys
            .where((String key) => key.contains('assets/logos/') && key.endsWith('.json'))
            .toList();
      } catch (e) {
        if (kDebugMode) print('LogoResolver: Manifest failed, using fallback list');
      }

      // If manifest failed or returned nothing, force-add the primary ones
      if (logoPaths.isEmpty) {
        logoPaths = [
          'assets/logos/honduras.json',
          'assets/logos/mexico.json',
          'assets/logos/united_states.json',
          'assets/logos/spain.json'
        ];
      }

      final Map<String, Map<String, String>> nestedIndex = {};

      // 2. Load each file and aggregate into the nested index
      for (final path in logoPaths) {
        try {
          final content = await rootBundle.loadString(path);
          final List<dynamic> jsonList = json.decode(content);

          for (final item in jsonList) {
            try {
              final logo = JsonLogoItem.fromJson(item as Map<String, dynamic>);
              
              // Handle nesting by Country
              final countryKey = _normalizeCountry(logo.pais);
              final channelKey = _normalizeForLookup(logo.canal);
              
              if (kDebugMode && countryKey == 'honduras' && (nestedIndex['honduras']?.length ?? 0) < 5) {
                print('LogoResolver: Honduras item mapped: "$channelKey" -> ${logo.url.substring(0, 20)}...');
              }

              final countryMap = nestedIndex.putIfAbsent(countryKey, () => {});
              countryMap[channelKey] = logo.url;
            } catch (e) {
              // Skip bad items instead of breaking whole file
            }
          }
          if (kDebugMode) {
            print('LogoResolver: Loaded ${jsonList.length} items from $path');
          }
        } catch (e) {
          if (kDebugMode) print('LogoResolver Error loading $path: $e');
        }
      }

      state = nestedIndex;
      if (kDebugMode) {
        int total = 0;
        nestedIndex.forEach((_, map) => total += map.length);
        print('LogoResolver: Listed Country Keys: ${nestedIndex.keys.toList()}');
        if (nestedIndex.containsKey('honduras')) {
           print('LogoResolver: Honduras is REGISTERED with ${nestedIndex['honduras']!.length} logos');
        } else {
           print('LogoResolver: WARNING - Honduras NOT FOUND in index keys!');
        }
        print('LogoResolver: Indexed $total logos across ${nestedIndex.length} countries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('LogoResolver Global Error: $e');
      }
    } finally {
      _isLoading = false;
    }
  }

  String _normalizeCountry(String country) {
    return country.toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '')
        .trim();
  }


  String _normalizeForLookup(String name) {
    if (name.isEmpty) return '';
    var n = name.toLowerCase();

    // 1. Handle IPTV specific prefixes and symbols (HON|, HN:, TV-)
    final parts = n.split(RegExp(r'[|:/\-\\]'));
    if (parts.length > 1) {
      n = parts.last.trim();
    }

    // 2. Remove common country identifiers at the START
    n = n.replaceFirst(RegExp(r'^(hon|hnd|hn|es|esp|mx|mex|us|usa|latam|latino|televicentro|tvc)\b'), '');

    // 3. Remove common quality noise
    n = n.replaceAll(RegExp(r'\b(hd|fhd|uhd|4k|sd|1080p|720p|h264|h265|intl|latin|latam)\b'), ' ');

    // 4. Remove country extensions at the end (common in JSON)
    n = n.replaceFirst(RegExp(r'\.(hn|mx|es|us|ar|co|cl|pe|uy|ve|ec|bo|pa|do|ca|uk|br|pt|de|fr|gr|it)$'), '');

    // 5. Final cleaning: keep letters and numbers only
    return n.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
