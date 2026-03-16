import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      // In a real TV environment, we might want to use compute() if the JSON is very large
      // to avoid frame drops during warmup.
      final file = File('channel_logos.json');
      if (!await file.exists()) {
        _isLoading = false;
        return;
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);

      final Map<String, String> index = {};
      for (final item in jsonList) {
        final logo = JsonLogoItem.fromJson(item as Map<String, dynamic>);
        // Index by normalized name for O(1) lookup
        final key = _normalizeForLookup(logo.canal);
        index[key] = logo.url;
      }

      state = index;
      if (kDebugMode) {
        print('LogoResolver: Indexed ${index.length} logos from JSON');
      }
    } catch (e) {
      if (kDebugMode) {
        print('LogoResolver Error: $e');
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
