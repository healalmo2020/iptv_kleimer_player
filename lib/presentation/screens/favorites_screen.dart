import 'section_screen.dart';

class FavoritesScreen extends SectionScreen {
  const FavoritesScreen({super.key})
      : super(
          title: 'Favorites',
          description: 'Pantalla de favoritos conectada a persistencia local (Hive).',
        );
}
