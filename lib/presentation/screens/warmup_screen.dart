import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/channel_logo_resolver.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/live_provider.dart';
import '../providers/search_provider.dart';
import '../providers/series_provider.dart';
import '../providers/vod_provider.dart';

class WarmupScreen extends ConsumerStatefulWidget {
  const WarmupScreen({super.key});

  @override
  ConsumerState<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends ConsumerState<WarmupScreen> {
  static const int _maxLiveCategoriesToWarm = 4;
  static const int _maxLiveChannelsPerCategory = 15;
  static const int _maxVodCoversToWarm = 24;
  static const int _maxSeriesCoversToWarm = 18;
  static const int _maxUrlsToPrecache = 120;
  static const int _precacheConcurrency = 6;

  String _phaseText = 'Preparando contenido inicial...';
  int _completed = 0;
  int _planned = 1;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_runWarmup);
  }

  Future<void> _runWarmup() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      _goTo('/login');
      return;
    }

    final storage = ref.read(localStorageProvider);
    if (!storage.shouldRunDailyWarmup(username: session.username)) {
      _goTo('/home');
      return;
    }

    final urls = <String>{};

    // Prime the unified search index in the background so Search can
    // resolve queries locally without a first-open fetch.
    unawaited(() async {
      try {
        await ref.read(searchIndexProvider.future);
      } catch (_) {}
    }());

    _setPhase('Cargando categorías y canales en vivo...');
    try {
      final categories = await ref
          .read(liveCategoriesProvider.future)
          .timeout(const Duration(seconds: 12));

      for (final category in categories.take(_maxLiveCategoriesToWarm)) {
        final streams = await ref
            .read(liveStreamsByCategoryProvider(category.id).future)
            .timeout(const Duration(seconds: 12));

        for (final stream in streams.take(_maxLiveChannelsPerCategory)) {
          final repositoryLogo = resolveChannelLogoRepositoryUrl(
            channelName: stream.name,
          );
          final logoUrl = repositoryLogo.isNotEmpty
              ? repositoryLogo
              : (stream.iconUrl?.trim() ?? '');
          if (_isValidImageUrl(logoUrl)) {
            urls.add(logoUrl);
          }
        }
      }
    } catch (_) {}

    _setPhase('Preparando portadas de películas...');
    try {
      final vodItems = await ref
          .read(vodStreamsProvider.future)
          .timeout(const Duration(seconds: 12));
      for (final item in vodItems.take(_maxVodCoversToWarm)) {
        final cover = item.coverUrl?.trim() ?? '';
        if (_isValidImageUrl(cover)) {
          urls.add(cover);
        }
      }
    } catch (_) {}

    _setPhase('Preparando portadas de series...');
    try {
      final seriesItems = await ref
          .read(seriesProvider.future)
          .timeout(const Duration(seconds: 12));
      for (final item in seriesItems.take(_maxSeriesCoversToWarm)) {
        final cover = item.coverUrl?.trim() ?? '';
        if (_isValidImageUrl(cover)) {
          urls.add(cover);
        }
      }
    } catch (_) {}

    final queue = urls.take(_maxUrlsToPrecache).toList(growable: false);
    if (mounted) {
      setState(() {
        _planned = queue.isEmpty ? 1 : queue.length;
        _completed = 0;
      });
    }

    _setPhase('Optimizando imágenes para inicio rápido...');
    await _precacheInBatches(queue);

    await storage.markDailyWarmupRun(username: session.username);

    _goTo('/home');
  }

  Future<void> _precacheInBatches(List<String> urls) async {
    if (urls.isEmpty || !mounted) {
      return;
    }

    var index = 0;
    while (index < urls.length && mounted) {
      final end = (index + _precacheConcurrency).clamp(0, urls.length);
      final batch = urls.sublist(index, end);

      await Future.wait(batch.map(_precacheSingle));
      index = end;
    }
  }

  Future<void> _precacheSingle(String url) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _completed++;
        });
      }
    }
  }

  bool _isValidImageUrl(String value) {
    if (value.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    return uri.hasScheme && uri.host.isNotEmpty;
  }

  void _setPhase(String value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phaseText = value;
    });
  }

  void _goTo(String route) {
    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _planned <= 0
        ? 0.0
        : (_completed / _planned).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Preparando tu biblioteca',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _phaseText,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('$_completed / $_planned'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
