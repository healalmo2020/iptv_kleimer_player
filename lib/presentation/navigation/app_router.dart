import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/continue_watching_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/live/live_screen.dart';
import '../screens/login_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/player/player_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../screens/series_screen.dart';
import '../screens/series_detail_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/warmup_screen.dart';

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/warmup', builder: (_, _) => const WarmupScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/live', builder: (_, _) => const LiveScreen()),
      GoRoute(path: '/movies', builder: (_, _) => const MoviesScreen()),
      GoRoute(path: '/series', builder: (_, _) => const SeriesScreen()),
      GoRoute(
        path: '/series/details',
        builder: (_, state) => SeriesDetailScreen(
          seriesId: state.uri.queryParameters['id'] ?? '',
          title: state.uri.queryParameters['title'] ?? 'Series',
        ),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/continue', builder: (_, _) => const ContinueWatchingScreen()),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/player',
        builder: (_, state) => PlayerScreen(
          title: state.uri.queryParameters['title'] ?? 'Reproducción',
          streamId: state.uri.queryParameters['id'] ?? 'unknown',
          contentType: state.uri.queryParameters['type'] ?? 'live',
          extension: state.uri.queryParameters['ext'],
          nextEpisodeId: state.uri.queryParameters['nextId'],
          nextEpisodeTitle: state.uri.queryParameters['nextTitle'],
          nextEpisodeExtension: state.uri.queryParameters['nextExt'],
        ),
      ),
    ],
  );
}
