import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/json_logo_item.dart';

final logoResolverProvider = StateNotifierProvider<LogoResolverNotifier, Map<String, String>>((ref) {
  return LogoResolverNotifier();
});

class LogoResolverNotifier extends StateNotifier<Map<String, String>> {
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

      final Map<String, String> index = {};

      // 2. Load each file and aggregate into the index
      for (final path in logoPaths) {
        try {
          final content = await rootBundle.loadString(path);
          final List<dynamic> jsonList = json.decode(content);

          for (final item in jsonList) {
            final logo = JsonLogoItem.fromJson(item as Map<String, dynamic>);
            final key = _normalizeForLookup(logo.canal);
            index[key] = logo.url;
          }
        } catch (e) {
          if (kDebugMode) print('LogoResolver Error loading $path: $e');
        }
      }

      state = index;
      if (kDebugMode) {
        print('LogoResolver: Indexed ${index.length} logos from ${logoPaths.length} country files');
      }
    } catch (e) {
      if (kDebugMode) {
        print('LogoResolver Global Error: $e');
      }
    } finally {
      _isLoading = false;
    }
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
