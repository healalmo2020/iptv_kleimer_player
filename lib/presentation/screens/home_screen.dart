import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String route, IconData icon})>[
      (title: 'Live TV', route: '/live', icon: Icons.live_tv),
      (title: 'Movies', route: '/movies', icon: Icons.movie_outlined),
      (title: 'Series', route: '/series', icon: Icons.tv),
      (title: 'Search', route: '/search', icon: Icons.search),
      (title: 'Favorites', route: '/favorites', icon: Icons.favorite_outline),
      (title: 'Continue Watching', route: '/continue', icon: Icons.play_circle_outline),
      (title: 'History', route: '/history', icon: Icons.history),
      (title: 'Settings', route: '/settings', icon: Icons.settings_outlined),
      (title: 'Profile', route: '/profile', icon: Icons.person_outline),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('IPTV Kleimer Player')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 240,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF162544), Color(0xFF0B1426)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Hero Banner', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sections
                .map(
                  (e) => SizedBox(
                    width: 220,
                    child: Focus(
                      child: Builder(
                        builder: (context) {
                          final hasFocus = Focus.of(context).hasFocus;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: hasFocus ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                            child: Card(
                              child: ListTile(
                                leading: Icon(e.icon),
                                title: Text(e.title),
                                onTap: () => context.go(e.route),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
