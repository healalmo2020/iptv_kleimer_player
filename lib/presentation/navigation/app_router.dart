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
import '../screens/settings_screen.dart';

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/live', builder: (_, __) => const LiveScreen()),
      GoRoute(path: '/movies', builder: (_, __) => const MoviesScreen()),
      GoRoute(path: '/series', builder: (_, __) => const SeriesScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
      GoRoute(path: '/continue', builder: (_, __) => const ContinueWatchingScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/player',
        builder: (_, state) => PlayerScreen(
          title: state.uri.queryParameters['title'] ?? 'Reproducción',
          streamId: state.uri.queryParameters['id'] ?? 'unknown',
        ),
      ),
    ],
  );
}
