import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final supportDirectory = await getApplicationSupportDirectory();
  final hiveDirectory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}hive',
  );
  if (!await hiveDirectory.exists()) {
    await hiveDirectory.create(recursive: true);
  }

  await _initializeHive(hiveDirectory);

  runApp(const ProviderScope(child: IptvKleimerApp()));
}

Future<void> _initializeHive(Directory hiveDirectory) async {
  await Hive.initFlutter(hiveDirectory.path);

  const boxNames = <String>['app_settings', 'playback', 'favorites', 'history'];
  const maxAttempts = 4;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      for (final name in boxNames) {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox<dynamic>(name);
        }
      }
      return;
    } on PathAccessException catch (error) {
      if (!_isHiveLockError(error) || attempt == maxAttempts) {
        rethrow;
      }

      await Hive.close();
      await _deleteStaleHiveLocks(hiveDirectory);
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
}

bool _isHiveLockError(PathAccessException error) {
  final lockPath = error.path?.toLowerCase() ?? '';
  return lockPath.endsWith('.lock') && error.osError?.errorCode == 33;
}

Future<void> _deleteStaleHiveLocks(Directory hiveDirectory) async {
  await for (final entity in hiveDirectory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    if (!entity.path.toLowerCase().endsWith('.lock')) {
      continue;
    }

    try {
      await entity.delete();
    } on FileSystemException {
      // If another process still holds the lock file, keep retrying with backoff.
      continue;
    }
  }
}
