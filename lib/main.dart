import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('app_settings');
  await Hive.openBox<dynamic>('playback');
  await Hive.openBox<dynamic>('favorites');
  await Hive.openBox<dynamic>('history');

  runApp(const ProviderScope(child: IptvKleimerApp()));
}
