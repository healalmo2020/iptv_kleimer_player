import 'dart:core';

import '../../services/local_storage_service.dart';

class PlayerBufferConfig {
  const PlayerBufferConfig({
    required this.stallWatchdogThreshold,
    required this.vlcNetworkCachingMs,
    required this.vlcLiveCachingMs,
    required this.vlcFileCachingMs,
    required this.mediaKitBufferBytes,
  });

  final Duration stallWatchdogThreshold;
  final int vlcNetworkCachingMs;
  final int vlcLiveCachingMs;
  final int vlcFileCachingMs;
  final int mediaKitBufferBytes;
}

class PlayerBufferConstants {
  const PlayerBufferConstants._();

  // Low-latency profile: faster start, more sensitive to weak networks.
  static const PlayerBufferConfig fast = PlayerBufferConfig(
    stallWatchdogThreshold: Duration(seconds: 20),
    vlcNetworkCachingMs: 3000,
    vlcLiveCachingMs: 3000,
    vlcFileCachingMs: 2000,
    mediaKitBufferBytes: 32 * 1024 * 1024,
  );

  // Balanced profile: moderate startup with better resilience.
  static const PlayerBufferConfig balanced = PlayerBufferConfig(
    stallWatchdogThreshold: Duration(seconds: 30),
    vlcNetworkCachingMs: 8000,
    vlcLiveCachingMs: 8000,
    vlcFileCachingMs: 5000,
    mediaKitBufferBytes: 48 * 1024 * 1024,
  );

  // Stability-first profile: bigger cache for consistently bad networks.
  static const PlayerBufferConfig stable = PlayerBufferConfig(
    stallWatchdogThreshold: Duration(seconds: 45),
    vlcNetworkCachingMs: 12000,
    vlcLiveCachingMs: 12000,
    vlcFileCachingMs: 8000,
    mediaKitBufferBytes: 64 * 1024 * 1024,
  );

  static PlayerBufferConfig configForProfile(PlayerBufferProfile profile) {
    return switch (profile) {
      PlayerBufferProfile.fast => fast,
      PlayerBufferProfile.balanced => balanced,
      PlayerBufferProfile.stable => stable,
    };
  }
}
