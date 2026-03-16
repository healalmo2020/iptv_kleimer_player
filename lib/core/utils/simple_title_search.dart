import 'package:flutter/foundation.dart';

String normalizeTitle(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<T> applySimpleTitleQuery<T>({
  required List<T> items,
  required String query,
  required String Function(T item) titleSelector,
}) {
  final normalizedQuery = normalizeTitle(query);
  if (normalizedQuery.isEmpty) {
    return items;
  }

  final tokens = normalizedQuery
      .split(' ')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  final scored = <({T item, int score})>[];

  for (final item in items) {
    final rawTitle = titleSelector(item);
    if (rawTitle.isEmpty) {
      continue;
    }

    final title = normalizeTitle(rawTitle);
    if (title.isEmpty) {
      continue;
    }

    var score = 0;

    if (title.startsWith(normalizedQuery)) {
      score += 120;
    } else if (title.contains(normalizedQuery)) {
      score += 80;
    } else {
      var allTokensMatch = true;
      for (final token in tokens) {
        if (!title.contains(token)) {
          allTokensMatch = false;
          break;
        }
      }
      if (!allTokensMatch) {
        continue;
      }
      score += 50;
    }

    for (final token in tokens) {
      if (token.isEmpty) {
        continue;
      }
      if (title.startsWith(token)) {
        score += 10;
      } else if (title.contains(token)) {
        score += 6;
      }
    }

    scored.add((item: item, score: score));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) {
      return byScore;
    }
    return a.item
        .toString()
        .toLowerCase()
        .compareTo(b.item.toString().toLowerCase());
  });

  if (kDebugMode) {
    // Useful to keep an eye on result sizes during tuning.
  }

  return scored.map((e) => e.item).toList(growable: false);
}

