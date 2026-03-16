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

    try {
      // 1. Find all logo assets using the manifest
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      final logoPaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/logos/') && key.endsWith('.json'))
          .toList();

      if (logoPaths.isEmpty) {
        if (kDebugMode) print('LogoResolver: No logo files found in assets/logos/');
        _isLoading = false;
        return;
      }

      final Map<String, Map<String, String>> nestedIndex = {};

      // 2. Load each file and aggregate into the nested index
      for (final path in logoPaths) {
        try {
          final content = await rootBundle.loadString(path);
          final List<dynamic> jsonList = json.decode(content);

          for (final item in jsonList) {
            final logo = JsonLogoItem.fromJson(item as Map<String, dynamic>);
            
            // Handle nesting by Country
            final countryKey = _normalizeCountry(logo.pais);
            final channelKey = _normalizeForLookup(logo.canal);
            
            final countryMap = nestedIndex.putIfAbsent(countryKey, () => {});
            countryMap[channelKey] = logo.url;
          }
        } catch (e) {
          if (kDebugMode) print('LogoResolver Error loading $path: $e');
        }
      }

      state = nestedIndex;
      if (kDebugMode) {
        int total = 0;
        nestedIndex.forEach((_, map) => total += map.length);
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
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  String _normalizeForLookup(String name) {
    if (name.isEmpty) return '';
    var n = name.toLowerCase();

    // 1. Extract part after | if present (IPTV categorization)
    if (n.contains('|')) {
      n = n.split('|').last.trim();
    }

    // 2. Remove common noise keywords at word boundaries
    n = n.replaceAll(
      RegExp(r'\b(hd|fhd|uhd|4k|sd|latam|latino|latinos|la|mx|es|us|pr|ar|br|cl|co|pe|uy|ve|ec|bo|pa|do|int|intl|international)\b'),
      ' ',
    );

    // 3. Remove country extensions at the END (common in the JSON entries)
    // Examples: .hn, .mx, .es, .us, .ar, .co, .cl, .pe, .uy, .ve, .ec, .bo, .pa, .do, .ca, .uk, .br, .pt, .de, .fr, .gr, .it
    n = n.replaceFirst(
      RegExp(r'\.(hn|mx|es|us|ar|co|cl|pe|uy|ve|ec|bo|pa|do|ca|uk|br|pt|de|fr|gr|it)$'),
      '',
    );

    // 4. Final cleaning: keep only alphanumeric
    return n.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }
}
